# SPDX-License-Identifier: GPL-3.0-or-later
# ------------------------------------------------------------
#  此为新月杀的项目组织文件，采用CMake+QT
# 2022-01-24 新建文件夹 2023-02-21 发布v0.0.1版本
# ------------------------------------------------------------

cmake_minimum_required(VERSION 3.16)

project(FreeKill VERSION 0.4.19)
add_definitions(-DFK_VERSION=\"${CMAKE_PROJECT_VERSION}\")

find_package(Qt6 REQUIRED COMPONENTS
  Network
)

if (NOT DEFINED FK_SERVER_ONLY)
  find_package(Qt6 REQUIRED COMPONENTS
    Gui
    Qml
    Widgets
    Multimedia
    QuickControls2
    LinguistTools
  )
else ()
  add_definitions(-DFK_SERVER_ONLY)
endif()

find_package(OpenSSL)
find_package(Lua)
find_package(SQLite3)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(REQUIRED_QT_VERSION "6.4")

include_directories(include/lua)
include_directories(include)
include_directories(include/libgit2)
include_directories(src)

file(GLOB SWIG_FILES "${PROJECT_SOURCE_DIR}/src/swig/*.i")
if (DEFINED FK_SERVER_ONLY)
  set(SWIG_SOURCE ${PROJECT_SOURCE_DIR}/src/swig/freekill-nogui.i)
else ()
  set(SWIG_SOURCE ${PROJECT_SOURCE_DIR}/src/swig/freekill.i)
endif ()

add_custom_command(
  OUTPUT ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
  DEPENDS ${SWIG_FILES}
  COMMENT "Generating freekill-wrap.cxx"
  COMMAND swig -c++ -lua -Wall -o
    ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
    ${SWIG_SOURCE}
)

qt_add_executable(FreeKill)

if (NOT DEFINED FK_SERVER_ONLY)
  qt_add_translations(FreeKill
    TS_FILES lang/zh_CN.ts
    QM_FILES_OUTPUT_VARIABLE zh_CN.qm

    TS_FILES lang/en_US.ts
    QM_FILES_OUTPUT_VARIABLE en_US.qm
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
