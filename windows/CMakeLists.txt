# windows/CMakeLists.txt
#
# CMake configuration for the RAR plugin on Windows.
# Builds the native RAR library using libarchive for RAR support.
#
# Dependencies:
# - libarchive (install via vcpkg: vcpkg install libarchive:x64-windows)
#
# The Flutter tooling requires CMake 3.14+
cmake_minimum_required(VERSION 3.14)

project(rar LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

# Plugin name must not be changed
set(PLUGIN_NAME "rar_plugin")

# Try to find libarchive via vcpkg or system paths
find_package(LibArchive QUIET)

if(LibArchive_FOUND)
  message(STATUS "Found libarchive: ${LibArchive_LIBRARIES}")
else()
  # Try to find manually in common locations
  find_path(LibArchive_INCLUDE_DIR archive.h
    PATHS
      "$ENV{VCPKG_ROOT}/installed/x64-windows/include"
      "C:/vcpkg/installed/x64-windows/include"
      "$ENV{PROGRAMFILES}/libarchive/include"
  )
  find_library(LibArchive_LIBRARY archive
    PATHS
      "$ENV{VCPKG_ROOT}/installed/x64-windows/lib"
      "C:/vcpkg/installed/x64-windows/lib"
      "$ENV{PROGRAMFILES}/libarchive/lib"
  )
  if(LibArchive_INCLUDE_DIR AND LibArchive_LIBRARY)
    set(LibArchive_FOUND TRUE)
    set(LibArchive_LIBRARIES ${LibArchive_LIBRARY})
    set(LibArchive_INCLUDE_DIRS ${LibArchive_INCLUDE_DIR})
    message(STATUS "Found libarchive manually: ${LibArchive_LIBRARY}")
  else()
    message(WARNING "libarchive not found. RAR FFI operations may fail at runtime.")
    message(WARNING "Install with: vcpkg install libarchive:x64-windows")
  endif()
endif()

# Native RAR library sources
set(RAR_NATIVE_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/rar_native.c"
)

# Build the native RAR library as a shared library (DLL)
add_library(rar_native SHARED ${RAR_NATIVE_SOURCES})

target_include_directories(rar_native PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)

if(LibArchive_FOUND)
  target_include_directories(rar_native PRIVATE ${LibArchive_INCLUDE_DIRS})
  target_link_libraries(rar_native PRIVATE ${LibArchive_LIBRARIES})
endif()

target_compile_definitions(rar_native PRIVATE RAR_NATIVE_EXPORTS)

set_target_properties(rar_native PROPERTIES
  OUTPUT_NAME "rar_native"
)

# Flutter plugin sources
list(APPEND PLUGIN_SOURCES
  "rar_plugin.cpp"
  "rar_plugin.h"
)

# Build the Flutter plugin
add_library(${PLUGIN_NAME} SHARED
  "include/rar/rar_plugin_c_api.h"
  "rar_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Bundle the native RAR library with the plugin
set(rar_bundled_libraries
  "$<TARGET_FILE:rar_native>"
  PARENT_SCOPE
)

# === Tests ===
if(${include_${PROJECT_NAME}_tests})
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
    test/rar_plugin_test.cpp
    ${PLUGIN_SOURCES}
  )
  apply_standard_settings(${TEST_RUNNER})
  target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
  target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
  )

  include(GoogleTest)
  gtest_discover_tests(${TEST_RUNNER})
endif()
