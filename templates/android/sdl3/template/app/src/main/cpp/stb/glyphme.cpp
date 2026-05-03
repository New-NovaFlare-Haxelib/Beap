// glyphme.cpp - Font rendering library for HashLink/Heaps
// Supports both stb_truetype (TTF) and FreeType (OTF/CFF) backends

#include <stdint.h>

// Try to include FreeType if available
#if defined(USE_FREETYPE)
    #define HAS_FREETYPE
    #include <ft2build.h>
    #include FT_FREETYPE_H
    #include FT_GLYPH_H
    #include FT_OUTLINE_H
#endif

// stb_truetype for TTF support
#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"

#define HL_NAME(n) glyphme_##n

#include <hl.h>


// =============================================================================
// stb_truetype backend (original implementation)
// =============================================================================

HL_PRIM int HL_NAME(get_kerning)(const stbtt_fontinfo *font_info, int g1, int g2)
{
    return stbtt_GetGlyphKernAdvance(font_info, g1, g2);
}

HL_PRIM vdynamic *HL_NAME(get_glyph)(int code_point, const stbtt_fontinfo *font_info, float scale, int padding, int onedge_value, float pixel_dist_scale)
{
    auto glyph_index = stbtt_FindGlyphIndex(font_info, code_point);
    if (!glyph_index)
        return NULL;

    int advance_width = 0, left_side_bearing = 0;
    stbtt_GetGlyphHMetrics(font_info, glyph_index, &advance_width, &left_side_bearing); // not in pixel dimensions
    advance_width *= scale;
    left_side_bearing *= scale; // HELP: i don't know what to do with this

    int width = 0, height = 0, offset_x = 0, offset_y = 0;
    auto sdf = stbtt_GetGlyphSDF(font_info, scale, glyph_index, padding, onedge_value, pixel_dist_scale, &width, &height, &offset_x, &offset_y);

    unsigned char *rgba = NULL;
    if (width != 0 && height != 0)
    {
        rgba = (unsigned char *)hl_gc_alloc_noptr(width * height * 4);

        // for debugging purposes, we only use the red channel anyway
        auto g = 100 + rand() % 155;
        auto b = 100 + rand() % 155;

        for (int y = 0; y < height; ++y)
        {
            for (int x = 0; x < width; ++x)
            {
                int sdf_index = y * width + x;
                int sdf_value = sdf[sdf_index];

                int rgba_index = 4 * sdf_index;
                rgba[rgba_index++] = sdf_value;
                rgba[rgba_index++] = g;
                rgba[rgba_index++] = b;
                rgba[rgba_index++] = 255;
            }
        }
    }

    stbtt_FreeSDF(sdf, NULL);

    vdynamic *glyph_info = (vdynamic *)hl_alloc_dynobj();
    hl_dyn_seti(glyph_info, hl_hash_utf8("index"), &hlt_i32, glyph_index);
    hl_dyn_seti(glyph_info, hl_hash_utf8("codePoint"), &hlt_i32, code_point);
    hl_dyn_setp(glyph_info, hl_hash_utf8("rgba"), &hlt_bytes, rgba);
    hl_dyn_seti(glyph_info, hl_hash_utf8("width"), &hlt_i32, width);
    hl_dyn_seti(glyph_info, hl_hash_utf8("height"), &hlt_i32, height);
    hl_dyn_seti(glyph_info, hl_hash_utf8("offsetX"), &hlt_i32, offset_x);
    hl_dyn_seti(glyph_info, hl_hash_utf8("offsetY"), &hlt_i32, offset_y);
    hl_dyn_seti(glyph_info, hl_hash_utf8("advanceX"), &hlt_i32, advance_width);

    return glyph_info;
}

HL_PRIM int HL_NAME(get_number_of_fonts)(const vbyte *font_file_bytes)
{
    return stbtt_GetNumberOfFonts(font_file_bytes);
}

HL_PRIM vdynamic *HL_NAME(get_true_type_font_info)(const vbyte *font_file_bytes, int font_index)
{
    auto stbtt_info = (stbtt_fontinfo *)hl_gc_alloc_noptr(sizeof(stbtt_fontinfo));
    auto font_offset = stbtt_GetFontOffsetForIndex(font_file_bytes, font_index);
    if (font_offset == -1)
        return NULL;

    auto success = stbtt_InitFont(stbtt_info, font_file_bytes, font_offset);
    if (!success)
    {
        // free(stbtt_info); //HELP: i don't know how to free this, or if the gc will do it for me?
        return NULL;
    }

    int ascent = 0, descent = 0, line_gap = 0;
    stbtt_GetFontVMetrics(stbtt_info, &ascent, &descent, &line_gap);

    auto font_info = (vdynamic *)hl_alloc_dynobj();
    hl_dyn_setp(font_info, hl_hash_utf8("stbttFontInfo"), &hlt_bytes, stbtt_info);
    hl_dyn_seti(font_info, hl_hash_utf8("ascent"), &hlt_i32, ascent);
    hl_dyn_seti(font_info, hl_hash_utf8("descent"), &hlt_i32, descent);
    hl_dyn_seti(font_info, hl_hash_utf8("lineGap"), &hlt_i32, line_gap);

    return font_info;
}

// =============================================================================
// FreeType backend (for better OTF/CFF support)
// =============================================================================

#ifdef HAS_FREETYPE

static FT_Library ft_library = NULL;

// Initialize FreeType library
static int init_freetype() {
    if (ft_library != NULL) return 1;
    FT_Error error = FT_Init_FreeType(&ft_library);
    return error == 0;
}

// Font face wrapper structure
typedef struct {
    FT_Face face;
    unsigned char* data;
    int data_size;
} FontFace;

// Check if font format requires FreeType backend
// (OTF/CFF, WOFF, WOFF2 - stb_truetype cannot handle these)
static int is_freetype_font(const unsigned char* data, int size) {
    if (size < 4) return 0;
    // Check for 'OTTO' signature (OpenType with CFF)
    if (data[0] == 'O' && data[1] == 'T' && data[2] == 'T' && data[3] == 'O')
        return 1;
    // Check for WOFF (Web Open Font Format)
    if (data[0] == 'w' && data[1] == 'O' && data[2] == 'F' && data[3] == 'F')
        return 1;
    // Check for WOFF2
    if (data[0] == 'w' && data[1] == 'O' && data[2] == 'F' && data[3] == '2')
        return 1;
    // Check for TrueType Collection
    if (data[0] == 't' && data[1] == 't' && data[2] == 'c' && data[3] == 'f')
        return 0; // TTC handled by stb_truetype
    // Check for TrueType
    if (data[0] == 0x00 && data[1] == 0x01 && data[2] == 0x00 && data[3] == 0x00)
        return 0; // TTF handled by stb_truetype
    return 1; // Assume FreeType font for other cases
}

HL_PRIM int HL_NAME(ft_init)() {
    return init_freetype();
}

HL_PRIM int HL_NAME(ft_is_otf)(const vbyte* font_data, int data_size) {
    return is_freetype_font(font_data, data_size);
}

HL_PRIM vdynamic* HL_NAME(ft_get_font_info)(const vbyte* font_data, int data_size, int font_index) {
    if (!init_freetype()) return NULL;
    
    // Allocate and copy font data (FreeType needs to keep it)
    unsigned char* data_copy = (unsigned char*)hl_gc_alloc_noptr(data_size);
    memcpy(data_copy, font_data, data_size);
    
    FT_Face face;
    FT_Error error = FT_New_Memory_Face(ft_library, data_copy, data_size, font_index, &face);
    
    if (error != 0) {
        return NULL;
    }
    
    // Get font metrics
    FT_Int ascent = face->ascender;
    FT_Int descent = face->descender;
    FT_Int line_gap = face->height - (ascent - descent);
    
    vdynamic* font_info = (vdynamic*)hl_alloc_dynobj();
    // Store the FT_Face pointer as two 32-bit integers (high and low)
    size_t face_ptr = (size_t)face;
    hl_dyn_seti(font_info, hl_hash_utf8("ftFaceLow"), &hlt_i32, (int32_t)(face_ptr & 0xFFFFFFFF));
    hl_dyn_seti(font_info, hl_hash_utf8("ftFaceHigh"), &hlt_i32, (int32_t)(face_ptr >> 32));
    hl_dyn_seti(font_info, hl_hash_utf8("ascent"), &hlt_i32, ascent);
    hl_dyn_seti(font_info, hl_hash_utf8("descent"), &hlt_i32, descent);
    hl_dyn_seti(font_info, hl_hash_utf8("lineGap"), &hlt_i32, line_gap);
    hl_dyn_seti(font_info, hl_hash_utf8("numGlyphs"), &hlt_i32, face->num_glyphs);
    hl_dyn_seti(font_info, hl_hash_utf8("unitsPerEM"), &hlt_i32, face->units_per_EM);
    
    // Note: We need to keep the font data alive for FreeType
    // Store it in a global list or use GC to track it
    // For now, we'll just keep a reference in the font_info
    hl_dyn_setp(font_info, hl_hash_utf8("ftData"), &hlt_bytes, (vbyte*)data_copy);
    hl_dyn_seti(font_info, hl_hash_utf8("ftDataSize"), &hlt_i32, data_size);
    
    return font_info;
}

HL_PRIM int HL_NAME(ft_get_number_of_fonts)(const vbyte* font_data, int data_size) {
    if (!init_freetype()) return -1;
    
    FT_Face face;
    FT_Error error = FT_New_Memory_Face(ft_library, font_data, data_size, -1, &face);
    
    if (error != 0) {
        // Try with index 0
        error = FT_New_Memory_Face(ft_library, font_data, data_size, 0, &face);
        if (error != 0) return -1;
        FT_Done_Face(face);
        return 1;
    }
    
    int num_faces = face->num_faces;
    FT_Done_Face(face);
    return num_faces;
}

HL_PRIM int HL_NAME(ft_get_kerning)(int face_ptr_low, int face_ptr_high, int g1, int g2) {
    size_t face_ptr = ((size_t)(uint32_t)face_ptr_high << 32) | (uint32_t)face_ptr_low;
    FT_Face face = (FT_Face)face_ptr;
    if (!face) return 0;
    
    FT_Vector kerning;
    FT_Error error = FT_Get_Kerning(face, g1, g2, FT_KERNING_DEFAULT, &kerning);
    
    if (error != 0) return 0;
    
    return kerning.x;
}

HL_PRIM vdynamic* HL_NAME(ft_get_glyph)(int code_point, int face_ptr_low, int face_ptr_high, float scale, int padding, int onedge_value, float pixel_dist_scale) {
    size_t face_ptr = ((size_t)(uint32_t)face_ptr_high << 32) | (uint32_t)face_ptr_low;
    FT_Face face = (FT_Face)face_ptr;
    
    if (!face) {
        return NULL;
    }
    
    // Get glyph index
    FT_UInt glyph_index = FT_Get_Char_Index(face, code_point);
    if (glyph_index == 0) {
        return NULL;
    }
    
    // Set character size (scale is the font height in pixels)
    FT_Error error = FT_Set_Pixel_Sizes(face, 0, (FT_UInt)scale);
    if (error != 0) {
        return NULL;
    }
    
    // Load glyph
    error = FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
    if (error != 0) {
        return NULL;
    }
    
    // Render to bitmap
    // Use MONO rendering for pixel fonts to avoid anti-aliasing blur
    // Check if the font has a bitmap strike (pixel font) or if it's a pixel-style font
    FT_Render_Mode render_mode = FT_RENDER_MODE_NORMAL;
    
    // If the font has fixed sizes (bitmap/pixel font), use MONO rendering
    if (face->num_fixed_sizes > 0) {
        render_mode = FT_RENDER_MODE_MONO;
    }
    
    error = FT_Render_Glyph(face->glyph, render_mode);
    if (error != 0) {
        return NULL;
    }
    
    // Get metrics after rendering
    FT_Int advance_width = face->glyph->advance.x;
    FT_Int left_side_bearing = face->glyph->bitmap_left;
    
    FT_Bitmap* bitmap = &face->glyph->bitmap;
    int width = bitmap->width;
    int height = bitmap->rows;
    int offset_x = face->glyph->bitmap_left;
    // For FreeType, bitmap_top is the distance from the baseline to the top of the bitmap
    // We need to invert the Y axis to match stb_truetype's convention
    int offset_y = -(face->glyph->bitmap_top);
    
    // Convert to RGBA
    unsigned char* rgba = NULL;
    if (width > 0 && height > 0) {
        rgba = (unsigned char*)hl_gc_alloc_noptr(width * height * 4);
        
        if (bitmap->pixel_mode == FT_PIXEL_MODE_MONO) {
            // 1-bit monochrome bitmap - convert to RGBA
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    int byte_index = y * bitmap->pitch + (x >> 3);
                    int bit_index = 7 - (x & 7);
                    unsigned char pixel = (bitmap->buffer[byte_index] >> bit_index) & 1;
                    unsigned char alpha = pixel ? 255 : 0;
                    
                    int dst_index = (y * width + x) * 4;
                    rgba[dst_index + 0] = 255;    // R (white)
                    rgba[dst_index + 1] = 255;    // G (white)
                    rgba[dst_index + 2] = 255;    // B (white)
                    rgba[dst_index + 3] = alpha;  // A (transparency)
                }
            }
        } else {
            // 8-bit grayscale bitmap
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    int src_index = y * bitmap->pitch + x;
                    int dst_index = (y * width + x) * 4;
                    unsigned char alpha = bitmap->buffer[src_index];
                    
                    // For bitmap font rendering: white with alpha transparency
                    rgba[dst_index + 0] = 255;    // R (white)
                    rgba[dst_index + 1] = 255;    // G (white)
                    rgba[dst_index + 2] = 255;    // B (white)
                    rgba[dst_index + 3] = alpha;  // A (transparency)
                }
            }
        }
    }
    
    vdynamic* glyph_info = (vdynamic*)hl_alloc_dynobj();
    hl_dyn_seti(glyph_info, hl_hash_utf8("index"), &hlt_i32, glyph_index);
    hl_dyn_seti(glyph_info, hl_hash_utf8("codePoint"), &hlt_i32, code_point);
    hl_dyn_setp(glyph_info, hl_hash_utf8("rgba"), &hlt_bytes, rgba);
    hl_dyn_seti(glyph_info, hl_hash_utf8("width"), &hlt_i32, width);
    hl_dyn_seti(glyph_info, hl_hash_utf8("height"), &hlt_i32, height);
    hl_dyn_seti(glyph_info, hl_hash_utf8("offsetX"), &hlt_i32, offset_x);
    hl_dyn_seti(glyph_info, hl_hash_utf8("offsetY"), &hlt_i32, offset_y);
    hl_dyn_seti(glyph_info, hl_hash_utf8("advanceX"), &hlt_i32, advance_width >> 6); // Convert from 26.6 fixed point
    
    return glyph_info;
}

HL_PRIM void HL_NAME(ft_cleanup)() {
    if (ft_library != NULL) {
        FT_Done_FreeType(ft_library);
        ft_library = NULL;
    }
}

#else

// FreeType not available - provide stub functions
HL_PRIM int HL_NAME(ft_init)() { return 0; }
HL_PRIM int HL_NAME(ft_is_otf)(const vbyte* font_data, int data_size) { return 0; }
HL_PRIM vdynamic* HL_NAME(ft_get_font_info)(const vbyte* font_data, int data_size, int font_index) { return NULL; }
HL_PRIM int HL_NAME(ft_get_number_of_fonts)(const vbyte* font_data, int data_size) { return -1; }
HL_PRIM int HL_NAME(ft_get_kerning)(int face_ptr_low, int face_ptr_high, int g1, int g2) { return 0; }
HL_PRIM vdynamic* HL_NAME(ft_get_glyph)(int code_point, int face_ptr_low, int face_ptr_high, float scale, int padding, int onedge_value, float pixel_dist_scale) { return NULL; }
HL_PRIM void HL_NAME(ft_cleanup)() {}

#endif

DEFINE_PRIM(_I32, get_kerning, _BYTES _I32 _I32);
DEFINE_PRIM(_DYN, get_glyph, _I32 _BYTES _F32 _I32 _I32 _F32);
DEFINE_PRIM(_I32, get_number_of_fonts, _BYTES);
DEFINE_PRIM(_DYN, get_true_type_font_info, _BYTES _I32);

// FreeType backend primitives
// FreeType backend primitives
// Note: FT_Face is passed as two 32-bit integers (high and low)
DEFINE_PRIM(_I32, ft_init, _NO_ARG);
DEFINE_PRIM(_I32, ft_is_otf, _BYTES _I32);
DEFINE_PRIM(_DYN, ft_get_font_info, _BYTES _I32 _I32);
DEFINE_PRIM(_I32, ft_get_number_of_fonts, _BYTES _I32);
DEFINE_PRIM(_I32, ft_get_kerning, _I32 _I32 _I32 _I32);
DEFINE_PRIM(_DYN, ft_get_glyph, _I32 _I32 _I32 _F32 _I32 _I32 _F32);
DEFINE_PRIM(_VOID, ft_cleanup, _NO_ARG);