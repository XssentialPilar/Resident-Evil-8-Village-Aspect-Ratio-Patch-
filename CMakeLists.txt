cmake_minimum_required(VERSION 3.20)
project(RE8Display VERSION 2.5.0 LANGUAGES C CXX)

add_subdirectory(native)

include(CTest)
if(BUILD_TESTING)
    add_subdirectory(tests/standalone)
endif()
