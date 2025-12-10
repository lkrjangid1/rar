cmake_minimum_required(VERSION 3.10)

project(rar_native)

# Fetch libarchive
include(FetchContent)

FetchContent_Declare(
  libarchive
  URL https://github.com/libarchive/libarchive/releases/download/v3.7.2/libarchive-3.7.2.tar.gz
)

FetchContent_GetProperties(libarchive)
if(NOT libarchive_POPULATED)
  FetchContent_Populate(libarchive)
  
  # Configure libarchive to build only what we need
  set(ENABLE_TEST OFF CACHE BOOL "" FORCE)
  set(ENABLE_TAR OFF CACHE BOOL "" FORCE)
  set(ENABLE_CPIO OFF CACHE BOOL "" FORCE)
  set(ENABLE_CAT OFF CACHE BOOL "" FORCE)
  set(ENABLE_XATTR OFF CACHE BOOL "" FORCE)
  set(ENABLE_ACL OFF CACHE BOOL "" FORCE)
  set(ENABLE_ICONV OFF CACHE BOOL "" FORCE)
  set(ENABLE_EXPAT OFF CACHE BOOL "" FORCE)
  set(ENABLE_LIBXML2 OFF CACHE BOOL "" FORCE)
  
  # We only need RAR support
  # Note: libarchive's RAR support is built-in, but we might need zlib/lzma/etc for other formats
  # For now, we rely on minimal dependencies
  
  add_subdirectory(${libarchive_SOURCE_DIR} ${libarchive_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()

# Define our native library
add_library(rar_native SHARED
    ../src/rar_native.c
)

# Include directories
target_include_directories(rar_native PRIVATE
    ../src
    ${libarchive_SOURCE_DIR}/libarchive
    ${libarchive_BINARY_DIR} # For config.h
)

# Link against libarchive
target_link_libraries(rar_native
    archive_static
    log
)
