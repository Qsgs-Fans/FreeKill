# SPDX-License-Identifier: GPL-3.0-or-later
# ------------------------------------------------------------
#  此为新月杀的项目组织文件，采用CMake+QT
# 2022-01-24 新建文件夹 2023-02-21 发布v0.0.1版本
# ------------------------------------------------------------

cmake_minimum_required(VERSION 3.22)

project(FreeKill VERSION 0.5.20)
add_definitions(-DFK_VERSION=\"${CMAKE_PROJECT_VERSION}\")

find_package(Qt6 REQUIRED COMPONENTS
  Network
)

if (NOT DEFINED FK_SERVER_ONLY)
  find_package(Qt6 REQUIRED COMPONENTS
    Gui
    Qml
    Quick
    Widgets
    Multimedia
    QuickControls2
    Concurrent
    LinguistTools
  )
else ()
  add_definitions(-DFK_SERVER_ONLY)
endif()

if (DEFINED RPC_DEBUG)
  add_definitions(-DRPC_DEBUG)
endif()

set(CMAKE_COLOR_DIAGNOSTICS ON)

find_package(OpenSSL)
find_package(Lua)
find_package(SQLite3)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(REQUIRED_QT_VERSION "6.8")

include_directories(include)
include_directories(src)
# 谁加的，把我Github Action搞坏了，如果是MacOS的话麻烦加if吧我现在忙着调CI没空管
# include_directories(${LUA_INCLUDE_DIR})
# include_directories(${LIBGIT2_INCLUDE_DIRS})
include_directories(include/lua)
include_directories(include/libgit2)

if (${CMAKE_BUILD_TYPE}0 STREQUAL "Debug0")
  # add_compile_options(-fsanitize=address -fsanitize=undefined)
  # add_link_options(-fsanitize=address -fsanitize=undefined)
endif ()

if (DEFINED FK_USE_JEMALLOC)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules (JEMALLOC jemalloc)

  pkg_search_module(JEMALLOC REQUIRED jemalloc)
  include_directories(${JEMALLOC_INCLUDE_DIRS})
endif ()

qt_add_executable(FreeKill)

if (APPLE AND NOT IOS)
  set_target_properties(FreeKill PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "FreeKill"
    MACOSX_BUNDLE_GUI_IDENTIFIER "org.notify.FreeKill"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${CMAKE_PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${CMAKE_PROJECT_VERSION}"
  )
elseif (IOS)
  set_target_properties(FreeKill PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_BUNDLE_NAME "FreeKill"
    MACOSX_BUNDLE_GUI_IDENTIFIER "org.notify.FreeKill"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${CMAKE_PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${CMAKE_PROJECT_VERSION}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.notify.FreeKill"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST "NO"
  )
endif()

link_directories(${LIBGIT2_LIBRARY_DIRS})

if (NOT DEFINED FK_SERVER_ONLY)
  qt_add_translations(FreeKill
    TS_FILES lang/zh_CN.ts
    QM_FILES_OUTPUT_VARIABLE zh_CN.qm

    TS_FILES lang/en_US.ts
    QM_FILES_OUTPUT_VARIABLE en_US.qm

    TS_FILES lang/vi_VN.ts
    QM_FILES_OUTPUT_VARIABLE vi_VN.qm
  )
endif()

if (APPLE)
  file(GLOB_RECURSE FK_APP_RESOURCES CONFIGURE_DEPENDS
    RELATIVE ${PROJECT_SOURCE_DIR}
    audio/*
    client/*
    Fk/*
    fonts/*
    image/*
    lua/*
    packages/init.sql
    packages/maneuvering/*
    packages/standard/*
    packages/standard_cards/*
    packages/test/*
    server/*
    fk_ver
  )
  qt_add_resources(FreeKill "app_resources"
    PREFIX "/res"
    BASE ${PROJECT_SOURCE_DIR}
    FILES ${FK_APP_RESOURCES}
  )
endif()

add_custom_command(
  TARGET FreeKill
  POST_BUILD
  COMMENT "Generating version file fk_ver"
  COMMAND echo ${CMAKE_PROJECT_VERSION} > ${PROJECT_SOURCE_DIR}/fk_ver
  COMMAND ${PROJECT_SOURCE_DIR}/genfkver.sh
)

add_subdirectory(src)

if (APPLE)
  qt_generate_deploy_qml_app_script(
    TARGET FreeKill
    OUTPUT_SCRIPT apple_deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
  )
  install(SCRIPT ${apple_deploy_script})
endif()

if (DEFINED FK_TESTS)
enable_testing()
add_subdirectory(test)
endif ()
