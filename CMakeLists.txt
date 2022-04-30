cmake_minimum_required(VERSION 3.16)

project(FreeKill VERSION 0.0.1)

find_package(Qt5 REQUIRED COMPONENTS
  Gui
  Qml
  Network
  Multimedia
)

find_package(Lua)
find_package(SQLite3)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(REQUIRED_QT_VERSION "5.15.2")

include_directories(include/lua)
include_directories(include/sqlite3)
include_directories(src)
include_directories(src/client)
include_directories(src/core)
include_directories(src/network)
include_directories(src/server)
include_directories(src/ui)

add_subdirectory(src)
