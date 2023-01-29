cmake_minimum_required(VERSION 3.16)

project(FreeKill VERSION 0.0.1)

if (NOT ${CMAKE_SYSTEM_NAME} MATCHES "Emscripten")
include_directories(fkparse/src)
add_subdirectory(fkparse)
endif ()

find_package(Qt6 REQUIRED COMPONENTS
  Gui
  Qml
  Widgets
  Network
  Multimedia
  QuickControls2
  LinguistTools
)

find_package(OpenSSL)
find_package(Lua)
find_package(SQLite3)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(REQUIRED_QT_VERSION "6.3")

include_directories(include/lua)
include_directories(include/sqlite3)
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
qt_add_translations(FreeKill
  TS_FILES lang/zh_CN.ts
  QM_FILES_OUTPUT_VARIABLE zh_CN.qm
)

if (${CMAKE_SYSTEM_NAME} MATCHES "Emscripten")
file(GLOB_RECURSE FK_RESOURCE_FILES
  RELATIVE ${PROJECT_SOURCE_DIR}
  *.lua *.qml *.js *.png *.jpg *.mp3
)
list(APPEND FK_RESOURCE_FILES "fonts/FZLBGBK.ttf")
qt_add_resources(FreeKill "qrc"
  PREFIX "/"
  FILES ${FK_RESOURCE_FILES}
)
endif()
add_subdirectory(src)
