# SPDX-License-Identifier: GPL-3.0-or-later

set(freekill_SRCS
  "main.cpp"
  "core/player.cpp"
  "core/util.cpp"
  "core/packman.cpp"
  "network/server_socket.cpp"
  "network/client_socket.cpp"
  "network/router.cpp"
  "server/auth.cpp"
  "server/server.cpp"
  "server/serverplayer.cpp"
  "server/roombase.cpp"
  "server/lobby.cpp"
  "server/room.cpp"
  "server/roomthread.cpp"
  "server/scheduler.cpp"
  "ui/qmlbackend.cpp"
  "swig/freekill-wrap.cxx"
)

if (NOT DEFINED FK_SERVER_ONLY)
  list(APPEND freekill_SRCS
    "client/client.cpp"
    "client/clientplayer.cpp"
    "client/replayer.cpp"
    # "ui/mod.cpp"
  )
endif ()

set(QT_LIB
  Qt6::Network
)

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
  list(APPEND freekill_SRCS ${app_icon_resource_windows})
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
else ()
  set(LUA_LIB lua5.4)
  set(SQLITE3_LIB sqlite3)
  set(CRYPTO_LIB OpenSSL::Crypto)
  set(READLINE_LIB readline)
  list(APPEND freekill_SRCS "server/shell.cpp")
  set(GIT_LIB git2)
endif ()

target_sources(FreeKill PRIVATE ${freekill_SRCS})
target_precompile_headers(FreeKill PRIVATE "pch.h")
target_link_libraries(FreeKill PRIVATE
  ${LUA_LIB}
  ${SQLITE3_LIB}
  ${CRYPTO_LIB}
  ${SSL_LIB}
  ${READLINE_LIB}
  ${QT_LIB}
  ${SSH_LIB}
  ${GIT_LIB}
  ${IDBFS_LIB}
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
    DESTINATION share/FreeKill
  )
endif()
