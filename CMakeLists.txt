cmake_minimum_required(VERSION 3.16)

project(FreeKill VERSION 0.0.1)

include_directories(fkparse/src)
add_subdirectory(fkparse)

find_package(Qt6 REQUIRED COMPONENTS
  Gui
  Qml
  Widgets
  Network
  Multimedia
)

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

file(GLOB SWIG_FILES "${PROJECT_SOURCE_DIR}/src/swig/*.i")
add_custom_command(
  OUTPUT ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
  DEPENDS ${SWIG_FILES}
  COMMENT "Generating freekill-wrap.cxx"
  COMMAND swig -c++ -lua -Wall -o
    ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
    ${PROJECT_SOURCE_DIR}/src/swig/freekill.i
)

qt_add_executable(FreeKill)
add_subdirectory(src)
