cmake_minimum_required(VERSION 3.15)
project(HazeSecurity VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/build)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/build)

set(SOURCES
    native-module/haze_security.cpp
)

set(HEADERS
    native-module/haze_security.h
)

add_library(haze_security SHARED ${SOURCES} ${HEADERS})

target_link_libraries(haze_security PRIVATE
    psapi
    kernel32
    wintrust
)

target_compile_definitions(haze_security PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)

set_target_properties(haze_security PROPERTIES
    OUTPUT_NAME "haze_security"
    PREFIX ""
    SUFFIX ".dll"
)

if(MSVC)
    target_compile_options(haze_security PRIVATE /W4 /EHsc)
endif()

install(TARGETS haze_security
    LIBRARY DESTINATION native-module
    RUNTIME DESTINATION native-module
)
