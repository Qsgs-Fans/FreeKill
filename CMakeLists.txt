cmake_minimum_required(VERSION 3.22)

project(FreeKill VERSION 0.0.1)

find_package(Qt5 REQUIRED COMPONENTS
    Gui
    Qml
    Network
    Multimedia
)

find_package(Lua)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(REQUIRED_QT_VERSION "5.15.2")

include_directories(${PROJECT_SOURCE_DIR}/)
include_directories(${LUA_INCLUDE_DIRECTORIES})
include_directories(src)
include_directories(src/client)
include_directories(src/core)
include_directories(src/network)
include_directories(src/server)
include_directories(src/ui)

add_subdirectory(src)
