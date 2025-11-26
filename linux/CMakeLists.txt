# linux/CMakeLists.txt
#
# CMake configuration for the RAR plugin on Linux.
# Builds the native RAR library using libarchive for RAR support.
#
# Dependencies:
# - libarchive (apt: libarchive-dev, dnf: libarchive-devel)
#
# The Flutter tooling requires CMake 3.10+
cmake_minimum_required(VERSION 3.10)

project(rar LANGUAGES C CXX)

# Plugin name must not be changed
set(PLUGIN_NAME "rar_plugin")

# Find libarchive
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBARCHIVE REQUIRED libarchive)

# Native RAR library sources
set(RAR_NATIVE_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/rar_native.c"
)

# Build the native RAR library as a shared library
add_library(rar_native SHARED ${RAR_NATIVE_SOURCES})

target_include_directories(rar_native PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
  ${LIBARCHIVE_INCLUDE_DIRS}
)

target_link_libraries(rar_native PRIVATE
  ${LIBARCHIVE_LIBRARIES}
)

target_compile_definitions(rar_native PRIVATE
  RAR_NATIVE_EXPORTS
)

set_target_properties(rar_native PROPERTIES
  C_VISIBILITY_PRESET hidden
  POSITION_INDEPENDENT_CODE ON
  OUTPUT_NAME "rar_native"
)

# Flutter plugin sources
list(APPEND PLUGIN_SOURCES
  "rar_plugin.cc"
)

# Build the Flutter plugin
add_library(${PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# Bundle the native RAR library with the plugin
set(rar_bundled_libraries
  "$<TARGET_FILE:rar_native>"
  PARENT_SCOPE
)

# === Tests ===
if(${include_${PROJECT_NAME}_tests})
  if(${CMAKE_VERSION} VERSION_LESS "3.11.0")
    message("Unit tests require CMake 3.11.0 or later")
  else()
    set(TEST_RUNNER "${PROJECT_NAME}_test")
    enable_testing()

    include(FetchContent)
    FetchContent_Declare(
      googletest
      URL https://github.com/google/googletest/archive/release-1.11.0.zip
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
    FetchContent_MakeAvailable(googletest)

    add_executable(${TEST_RUNNER}
      test/rar_plugin_test.cc
      ${PLUGIN_SOURCES}
    )
    apply_standard_settings(${TEST_RUNNER})
    target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_link_libraries(${TEST_RUNNER} PRIVATE flutter)
    target_link_libraries(${TEST_RUNNER} PRIVATE PkgConfig::GTK)
    target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)

    include(GoogleTest)
    gtest_discover_tests(${TEST_RUNNER})
  endif()
endif()
