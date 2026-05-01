cmake_minimum_required(VERSION 3.10)
project(MyGame)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Source files
file(GLOB_RECURSE SOURCES
    "src/*.c"
    "hashlink/*.c"
    "hashlink/*.h"
)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/hashlink
    ${CMAKE_CURRENT_SOURCE_DIR}/sdl3/include
    ${CMAKE_CURRENT_SOURCE_DIR}/stb
    ${CMAKE_CURRENT_SOURCE_DIR}/libuv/include
    ${CMAKE_CURRENT_SOURCE_DIR}/openal-soft/include
    ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo
)

# SDL3 library
if(WIN32)
    set(SDL3_LIBRARY ${CMAKE_CURRENT_SOURCE_DIR}/sdl3/lib/x64/SDL3.lib)
    set(SDL3_DLL ${CMAKE_CURRENT_SOURCE_DIR}/sdl3/lib/x64/SDL3.dll)
elseif(ANDROID)
    set(SDL3_LIBRARY ${CMAKE_CURRENT_SOURCE_DIR}/sdl3/lib/${ANDROID_ABI}/libSDL3.so)
endif()

# Libraries
set(LIBS
    ${SDL3_LIBRARY}
    ${CMAKE_CURRENT_SOURCE_DIR}/libuv/lib/libuv.a
    ${CMAKE_CURRENT_SOURCE_DIR}/openal-soft/lib/libopenal.a
    ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg-turbo/lib/libjpeg.a
)

if(WIN32)
    list(APPEND LIBS
        ws2_32
        userenv
        iphlpapi
        psapi
        winmm
        ole32
        oleaut32
        uuid
        version
        advapi32
        setupapi
        shell32
        gdi32
    )
elseif(ANDROID)
    list(APPEND LIBS
        log
        android
        OpenSLES
        EGL
        GLESv2
    )
endif()

# Executable
if(WIN32)
    add_executable(MyGame WIN32 ${SOURCES})
else()
    add_executable(MyGame ${SOURCES})
endif()

target_link_libraries(MyGame ${LIBS})

# Copy SDL3 DLL on Windows
if(WIN32)
    add_custom_command(TARGET MyGame POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${SDL3_DLL}
        $<TARGET_FILE_DIR:MyGame>
    )
endif()
