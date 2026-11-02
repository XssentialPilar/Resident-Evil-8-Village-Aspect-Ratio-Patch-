cmake_minimum_required(VERSION 3.20)
project(RE8Display VERSION 2.1.0 LANGUAGES C CXX RC)

if(NOT WIN32 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "RE8Display requires Windows x64.")
endif()
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(RE8_EXTERNAL "${CMAKE_CURRENT_SOURCE_DIR}/../external")
set(RE8_MINHOOK "${RE8_EXTERNAL}/minhook")
if(NOT EXISTS "${RE8_EXTERNAL}/reframework-sdk/reframework/API.hpp" OR NOT EXISTS "${RE8_MINHOOK}/include/MinHook.h")
    message(FATAL_ERROR "Missing vendored REFramework API or MinHook sources; use the complete source checkout.")
endif()

add_library(RE8DisplayMinHook STATIC
    "${RE8_MINHOOK}/src/buffer.c"
    "${RE8_MINHOOK}/src/hook.c"
    "${RE8_MINHOOK}/src/trampoline.c"
    "${RE8_MINHOOK}/src/hde/hde64.c"
)
target_include_directories(RE8DisplayMinHook PUBLIC "${RE8_MINHOOK}/include")
target_compile_definitions(RE8DisplayMinHook PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)

add_library(RE8Display SHARED plugin/RE8Plugin.cpp plugin/RE8Display.rc)
target_compile_features(RE8Display PRIVATE cxx_std_23)
target_include_directories(RE8Display PRIVATE "${RE8_EXTERNAL}/reframework-sdk" "${RE8_MINHOOK}/src/hde")
target_compile_definitions(RE8Display PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE RE8_PLUGIN_WITH_MINHOOK=1)
target_link_libraries(RE8Display PRIVATE RE8DisplayMinHook user32 comctl32 dxgi)
set_target_properties(RE8Display PROPERTIES OUTPUT_NAME RE8Display PREFIX "")
if(MSVC)
    target_compile_options(RE8Display PRIVATE /W4 /permissive- /EHsc)
endif()
