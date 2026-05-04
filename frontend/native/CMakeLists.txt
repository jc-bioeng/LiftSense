cmake_minimum_required(VERSION 3.10)
project(liftsense_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ─── Sources ─────────────────────────────────────────────────
add_library(liftsense_core SHARED
    src/csv_parser.cpp
    src/biomechanics_engine.cpp
    src/coordinate_mapper.cpp
    src/frame_query.cpp
    src/ffi_api.cpp
)

target_include_directories(liftsense_core PUBLIC include/)

# ─── Symbol Visibility ──────────────────────────────────────
# Default: hide all symbols. Only EXPORT-marked functions are visible to Dart FFI.
set_target_properties(liftsense_core PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    POSITION_INDEPENDENT_CODE ON
)

# ─── Platform-specific flags ────────────────────────────────
if(ANDROID)
    target_link_libraries(liftsense_core PRIVATE log)
    # Android NDK: use c++_shared STL
    # (set via gradle: arguments "-DANDROID_STL=c++_shared")
endif()

# ─── Optional: Host tests build ─────────────────────────────
option(LIFTSENSE_BUILD_TESTS "Build unit tests for host" OFF)
if(LIFTSENSE_BUILD_TESTS AND NOT ANDROID)
    add_executable(liftsense_tests tests/test_main.cpp)
    target_link_libraries(liftsense_tests PRIVATE liftsense_core)
endif()
