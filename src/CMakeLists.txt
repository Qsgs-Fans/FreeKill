set(freekill_SRCS
  "main.cpp"
  "core/player.cpp"
  "core/util.cpp"
  "core/parser.cpp"
  "core/packman.cpp"
  "network/server_socket.cpp"
  "network/client_socket.cpp"
  "network/router.cpp"
  "server/server.cpp"
  "server/serverplayer.cpp"
  "server/room.cpp"
  "swig/freekill-wrap.cxx"
)

if (NOT DEFINED FK_SERVER_ONLY)
  list(APPEND freekill_SRCS
    "client/client.cpp"
    "client/clientplayer.cpp"
    "ui/qmlbackend.cpp"
  )
endif ()

set(FKP_LIB fkparse)
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
  set(GIT_LIB ${PROJECT_SOURCE_DIR}/lib/android/libgit2.so)
  set_target_properties(FreeKill PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR ${PROJECT_SOURCE_DIR}/android
    QT_ANDROID_EXTRA_LIBS "${LUA_LIB};${SQLITE3_LIB};${CRYPTO_LIB};${SSL_LIB};${GIT_LIB}"
  )
  list(REMOVE_ITEM QT_LIB Qt6::QuickControls2)
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Emscripten")
  # WASM
  list(REMOVE_ITEM freekill_SRCS
    "network/server_socket.cpp"
    #"network/client_socket.cpp"
    #"network/router.cpp"
    "server/server.cpp"
    "server/serverplayer.cpp"
    "server/room.cpp"
  )
  set(FKP_LIB "")
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/wasm/liblua.a)
  set(CRYPTO_LIB ${PROJECT_SOURCE_DIR}/lib/wasm/libcrypto.a)
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
  ${FKP_LIB}
  ${QT_LIB}
  ${GIT_LIB}
)

install(TARGETS FreeKill DESTINATION bin)
install(TARGETS fkparse DESTINATION lib)
