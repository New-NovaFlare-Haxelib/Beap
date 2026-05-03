cmake_minimum_required(VERSION 3.1)
project(heapsapp)

add_definitions(-DANDROID_PLATFORM=android-24)

# 路径变量
set(FREETYPE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/freetype)
set(HL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/hashlink)
set(JNI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../jni)

include_directories(${HL_DIR}/src)
include_directories(${HL_DIR}/include)
include_directories(${HL_DIR}/include/pcre)

# --- PCRE ---
file(GLOB pcre_srcs ${HL_DIR}/include/pcre/*.c)
list(REMOVE_ITEM pcre_srcs
    ${HL_DIR}/include/pcre/pcre2_jit_match.c
    ${HL_DIR}/include/pcre/pcre2_jit_misc.c
)

# --- HL 核心 ---
file(GLOB libhl_srcs
    ${HL_DIR}/src/std/*.c
    ${HL_DIR}/src/alloc.c
    ${HL_DIR}/src/gc.c
)
file(GLOB mbedtls_srcs ${HL_DIR}/include/mbedtls/library/*.c)
list(APPEND libhl_srcs ${HL_DIR}/src/std/sys_android.c)
list(APPEND libhl_srcs ${HL_DIR}/libs/ssl/ssl.c)

add_library(hl STATIC ${pcre_srcs} ${libhl_srcs} ${mbedtls_srcs})
target_include_directories(hl PRIVATE ${HL_DIR}/include/pcre)
target_include_directories(hl PRIVATE ${HL_DIR}/include/mbedtls/include)
target_link_libraries(hl log)
target_compile_definitions(hl PRIVATE _USRDLL LIBHL_EXPORTS HAVE_CONFIG_H PCRE2_CODE_UNIT_WIDTH=16)

# --- libjpeg-turbo ---
set(TJ_LIB ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo/obj/local/${ANDROID_ABI}/libjpeg-turbo.a)
add_custom_target(turbojpeg ALL
    COMMAND ${ANDROID_NDK}/ndk-build
    APP_ABI=${ANDROID_ABI}
    APP_PLATFORM=${ANDROID_PLATFORM}
    NDK_PROJECT_PATH=./libjpeg-turbo
    WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    BYPRODUCTS ${TJ_LIB}
)

# --- FMT ---
file(GLOB fmt_srcs ${HL_DIR}/libs/fmt/*.c)
file(GLOB png_srcs ${HL_DIR}/include/png/*.c)
file(GLOB zlib_srcs ${HL_DIR}/include/zlib/*.c)
file(GLOB vorbis_srcs ${HL_DIR}/include/vorbis/*.c)
file(GLOB mikkt_srcs ${HL_DIR}/include/mikktspace/*.c)
file(GLOB minimp3_srcs ${HL_DIR}/include/minimp3/*.c)

add_library(fmt_hdll STATIC ${fmt_srcs} ${png_srcs} ${zlib_srcs} ${vorbis_srcs} ${mikkt_srcs} ${minimp3_srcs})
add_dependencies(fmt_hdll turbojpeg)
target_link_libraries(fmt_hdll ${TJ_LIB})
target_compile_definitions(fmt_hdll PRIVATE PNG_ARM_NEON_OPT=0)

file(GLOB tj_include ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo/jni/vendor/libjpeg-turbo/libjpeg-turbo-*)
target_include_directories(fmt_hdll PRIVATE
    ${HL_DIR}/include/png
    ${HL_DIR}/include/mikktspace
    ${HL_DIR}/include/minimp3
    ${HL_DIR}/include/vorbis
    ${HL_DIR}/include/zlib
    ${tj_include}
)

# --- SDL ---
add_subdirectory(sdl3)
file(GLOB sdl_srcs ${HL_DIR}/libs/sdl/*.c)
add_library(sdl_hdll STATIC ${sdl_srcs})
target_include_directories(sdl_hdll PUBLIC sdl3/include)
target_link_libraries(sdl_hdll SDL3::SDL3-shared EGL GLESv3)

# --- OpenAL (使用系统 OpenSLES，不编译 openal-soft) ---
file(GLOB openal_srcs ${HL_DIR}/libs/openal/*.c)
add_library(openal_hdll STATIC ${openal_srcs})
target_include_directories(openal_hdll PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/openal-soft/include)
target_link_libraries(openal_hdll OpenSLES)

# --- UI ---
add_library(ui_hdll STATIC ${HL_DIR}/libs/ui/ui_stub.c)

# --- libuv ---
add_subdirectory(libuv)
file(GLOB uv_srcs ${HL_DIR}/libs/uv/*.c)
add_library(uv_hdll STATIC ${uv_srcs})
target_include_directories(uv_hdll PUBLIC libuv/include)
target_link_libraries(uv_hdll uv)

# --- freetype ---
set(FT_DISABLE_BZIP2 ON CACHE BOOL "Disable bzip2" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "Disable PNG" FORCE)
set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "Disable HarfBuzz" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "Disable Brotli" FORCE)
set(FT_DISABLE_HVF ON CACHE BOOL "Disable HVF" FORCE)

add_subdirectory(${FREETYPE_DIR} freetype_build)

set(freetype_lib freetype)

# --- 自动链接预编译的 native 库 ---
file(GLOB native_libs ${CMAKE_CURRENT_SOURCE_DIR}/lib/${ANDROID_ABI}/*.so)
foreach(lib_path ${native_libs})
    get_filename_component(lib_name ${lib_path} NAME_WE)
    add_library(${lib_name} SHARED IMPORTED)
    set_target_properties(${lib_name} PROPERTIES
        IMPORTED_LOCATION ${lib_path}
    )
    message(STATUS "Auto-linked native library: ${lib_name} (${lib_path})")
endforeach()

# --- 主库 NexusForge ---
add_library(NexusForge SHARED
    ${JNI_DIR}/src/main.c
    ${CMAKE_CURRENT_SOURCE_DIR}/jni.c
    stb/glyphme.cpp
)

target_include_directories(NexusForge PRIVATE 
    ${JNI_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}
    stb
    ${FREETYPE_DIR}/include
    ${FREETYPE_DIR}/include/freetype
    ${CMAKE_CURRENT_BINARY_DIR}/freetype_build/include
)

# 链接库
target_link_libraries(NexusForge
    hl
    sdl_hdll
    fmt_hdll
    openal_hdll
    ui_hdll
    uv_hdll
    ${freetype_lib}
    ${native_libs}
    android
    log
)