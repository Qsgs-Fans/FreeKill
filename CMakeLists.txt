# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.16)

project(FreeKill VERSION 0.3.10)
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
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(REQUIRED_QT_VERSION "6.4")

include_directories(include/lua)
include_directories(include)
include_directories(include/libgit2)
include_directories(src)
include_directories(src/client)
include_directories(src/core)
include_directories(src/network)
include_directories(src/server)
include_directories(src/ui)

if (${CMAKE_SYSTEM_NAME} MATCHES "Emscripten")
# Fix include problem
include_directories("/usr/include/openssl-1.1/")
endif()

file(GLOB SWIG_FILES "${PROJECT_SOURCE_DIR}/src/swig/*.i")
if (${CMAKE_SYSTEM_NAME} MATCHES "Emscripten")
  set(SWIG_SOURCE ${PROJECT_SOURCE_DIR}/src/swig/freekill-wasm.i)
elseif (DEFINED FK_SERVER_ONLY)
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
  )
endif()

add_custom_command(
  TARGET FreeKill
  POST_BUILD
  COMMENT "Generating version file fk_ver"
  COMMAND echo ${CMAKE_PROJECT_VERSION} > ${PROJECT_SOURCE_DIR}/fk_ver
)

if (${CMAKE_SYSTEM_NAME} MATCHES "Emscripten")

  set(CMAKE_MODULE_LINKER_FLAGS ${CMAKE_MODULE_LINKER_FLAGS}
    "-s INITIAL_MEMORY=64MB"
  )

  file(GLOB_RECURSE FK_SCRIPT_FILES
    RELATIVE ${PROJECT_SOURCE_DIR}
    *.lua *.qml *.js *.fkp *.sql zh_CN.qm
  )
  qt_add_resources(FreeKill "scripts_qrc"
    PREFIX "/"
    FILES ${FK_SCRIPT_FILES}
  )

  qt_add_resources(FreeKill "font_qrc"
    PREFIX "/"
    FILES "fonts/FZLBGBK.ttf"
  )

  file(GLOB_RECURSE FK_IMG_FILES
    RELATIVE ${PROJECT_SOURCE_DIR}
    ${PROJECT_SOURCE_DIR}/image/*.jpg
    ${PROJECT_SOURCE_DIR}/image/*.png
  )
  qt_add_resources(FreeKill "img_qrc"
    PREFIX "/"
    FILES ${FK_IMG_FILES}
  )
  file(GLOB_RECURSE FK_AUDIO_FILES
    RELATIVE ${PROJECT_SOURCE_DIR}
    ${PROJECT_SOURCE_DIR}/audio/*.mp3
  )
  qt_add_resources(FreeKill "audio_qrc"
    PREFIX "/"
    FILES ${FK_AUDIO_FILES}
  )
  file(GLOB_RECURSE FK_PKG_FILES
    RELATIVE ${PROJECT_SOURCE_DIR}
    ${PROJECT_SOURCE_DIR}/packages/*.mp3
    ${PROJECT_SOURCE_DIR}/packages/*.jpg
    ${PROJECT_SOURCE_DIR}/packages/*.png
  )
  qt_add_resources(FreeKill "pkg_qrc"
    PREFIX "/"
    FILES ${FK_PKG_FILES}
  )

endif()

add_subdirectory(src)
