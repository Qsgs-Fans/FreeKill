# SPDX-License-Identifier: GPL-3.0-or-later

file(GLOB SWIG_FILES "${PROJECT_SOURCE_DIR}/src/swig/*.i")
set(SWIG_SOURCE ${PROJECT_SOURCE_DIR}/src/swig/freekill.i)

add_custom_command(
  OUTPUT ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
  DEPENDS ${SWIG_FILES}
  COMMENT "Generating freekill-wrap.cxx"
  COMMAND swig -c++ -lua -Wall -o
    ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
    ${SWIG_SOURCE}
)

set(freekill_EXESRCS
  "main.cpp"
)

set(freekill_SRCS
  # "main.cpp"
  "freekill.cpp"

  "core/player.cpp"
  "core/util.cpp"
  "core/c-wrapper.cpp"
  "core/packman.cpp"

  "client/client.cpp"
  "client/clientplayer.cpp"

  "network/server_socket.cpp"
  "network/client_socket.cpp"
  "network/router.cpp"

  "server/server.cpp"

  "server/user/auth.cpp"
  "server/user/serverplayer.cpp"
  "server/user/user_manager.cpp"

  "server/room/roombase.cpp"
  "server/room/lobby.cpp"
  "server/room/room.cpp"
  "server/room/room_manager.cpp"

  "server/rpc-lua/jsonrpc.cpp"
  "server/rpc-lua/rpc-lua.cpp"

  "server/gamelogic/roomthread.cpp"
  "server/gamelogic/rpc-dispatchers.cpp"

  "server/cli/shell.cpp"

  "ui/qmlbackend.cpp"

  "swig/freekill-wrap.cxx"
)
set_source_files_properties(
  "swig/freekill-wrap.cxx" PROPERTIES GENERATED TRUE)

if (NOT DEFINED FK_SERVER_ONLY)
  list(APPEND freekill_SRCS
    "client/replayer.cpp"
    # "ui/mod.cpp"
  )
endif ()

set(QT_LIB Qt6::Network)

if (NOT DEFINED FK_SERVER_ONLY)
  list(APPEND QT_LIB
    Qt6::Qml
    Qt6::Gui
    Qt6::Widgets
    Qt6::Multimedia
    Qt6::QuickControls2
  )
endif()

if (WIN32)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/win/lua54.dll)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/win/sqlite3.dll)
  set(CRYPTO_LIB OpenSSL::Crypto)
  set(GIT_LIB ${PROJECT_SOURCE_DIR}/lib/win/libgit2.dll)
  set(app_icon_resource_windows "${PROJECT_SOURCE_DIR}/image/icon.rc")
  list(APPEND freekill_EXESRCS ${app_icon_resource_windows})
elseif (ANDROID)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/android/liblua54.so)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/android/libsqlite3.so)
  set(CRYPTO_LIB ${PROJECT_SOURCE_DIR}/lib/android/libcrypto.so)
  set(SSL_LIB ${PROJECT_SOURCE_DIR}/lib/android/libssl.so)
  set(SSH_LIB ${PROJECT_SOURCE_DIR}/lib/android/libssh2.so)
  set(GIT_LIB ${PROJECT_SOURCE_DIR}/lib/android/libgit2.so)
  set_target_properties(FreeKill PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR ${PROJECT_SOURCE_DIR}/android
    QT_ANDROID_EXTRA_LIBS "${LUA_LIB};${SQLITE3_LIB};${CRYPTO_LIB};${SSL_LIB};${SSH_LIB};${GIT_LIB}"
  )
  list(REMOVE_ITEM QT_LIB Qt6::QuickControls2)
elseif (APPLE)
  set(LUA_LIB ${LUA_LIBRARIES})
  set(SQLITE3_LIB sqlite3)
  set(CRYPTO_LIB OpenSSL::Crypto)
  set(READLINE_LIB readline)

  set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "/opt/homebrew/Cellar/libgit2")
  find_package(PkgConfig)
  if (PkgConfig_FOUND)
    pkg_check_modules(LIBGIT2 libgit2)
    if (LIBGIT2_FOUND)
      message(STATUS "Found libgit2: ${LIBGIT2_LIBRARIES}")
    else ()
      message(WARNING "libgit2 not found, try to find libgit2 by CMake")
      find_package(LibGit2)
    endif ()
  else ()
    message(WARNING "PkgConfig not found, try to find libgit2 by CMake")
    find_package(LibGit2)
  endif ()
  set(GIT_LIB ${LIBGIT2_LIBRARIES})
  target_link_directories(FreeKill PRIVATE
    ${LIBGIT2_LIBRARY_DIRS}
  )
else ()
  set(LUA_LIB lua5.4)
  set(SQLITE3_LIB sqlite3)
  set(CRYPTO_LIB OpenSSL::Crypto)
  set(READLINE_LIB readline)
  set(GIT_LIB git2)
endif ()

add_library(libFreeKill STATIC ${freekill_SRCS})
target_precompile_headers(libFreeKill PRIVATE "pch.h")
target_link_libraries(libFreeKill PRIVATE
  ${LUA_LIB}
  ${SQLITE3_LIB}
  ${CRYPTO_LIB}
  ${SSL_LIB}
  ${READLINE_LIB}
  ${QT_LIB}
  ${SSH_LIB}
  ${GIT_LIB}
  ${IDBFS_LIB}
  ${JEMALLOC_LIBRARIES}
)

if (${CMAKE_BUILD_TYPE}0 STREQUAL "Debug0")
  target_compile_definitions(libFreeKill PRIVATE QT_QML_DEBUG)
endif ()

target_sources(FreeKill PRIVATE ${freekill_EXESRCS})
target_link_libraries(FreeKill PRIVATE
  libFreeKill
)

install(TARGETS FreeKill DESTINATION bin)
install(DIRECTORY
  ${PROJECT_SOURCE_DIR}/audio
  ${PROJECT_SOURCE_DIR}/fonts
  ${PROJECT_SOURCE_DIR}/image
  ${PROJECT_SOURCE_DIR}/lua
  ${PROJECT_SOURCE_DIR}/packages
  ${PROJECT_SOURCE_DIR}/Fk
  ${PROJECT_SOURCE_DIR}/server
  ${PROJECT_SOURCE_DIR}/client
  DESTINATION share/FreeKill
)
install(FILES
  ${PROJECT_SOURCE_DIR}/fk_ver
  DESTINATION share/FreeKill
)

if (NOT DEFINED FK_SERVER_ONLY)
  install(FILES
    ${CMAKE_BINARY_DIR}/zh_CN.qm
    ${CMAKE_BINARY_DIR}/en_US.qm
    ${CMAKE_BINARY_DIR}/vi_VN.qm
    DESTINATION share/FreeKill
  )
endif()
