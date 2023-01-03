set(freekill_SRCS
  "main.cpp"
  "core/player.cpp"
  "core/util.cpp"
  "network/server_socket.cpp"
  "network/client_socket.cpp"
  "network/router.cpp"
  "server/server.cpp"
  "server/serverplayer.cpp"
  "server/room.cpp"
  "client/client.cpp"
  "client/clientplayer.cpp"
  "ui/qmlbackend.cpp"
  "swig/freekill-wrap.cxx"
)

set(freekill_HEADERS
  "core/util.h"
  "core/player.h"
  "network/server_socket.h"
  "network/client_socket.h"
  "network/router.h"
  "server/server.h"
  "server/serverplayer.h"
  "server/room.h"
  "client/client.h"
  "client/clientplayer.h"
  "ui/qmlbackend.h"
)

set(FKP_LIB fkparse)
if (WIN32)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/win/lua54.dll)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/win/sqlite3.dll)
  set(CRYPTO_LIB OpenSSL::Crypto)
elseif (ANDROID)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/android/liblua54.so)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/android/libsqlite3.so)
  set(CRYPTO_LIB ${PROJECT_SOURCE_DIR}/lib/android/libcrypto_1_1.so)
  set_target_properties(FreeKill PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR ${PROJECT_SOURCE_DIR}/android
    QT_ANDROID_EXTRA_LIBS "${LUA_LIB};${SQLITE3_LIB};${CRYPTO_LIB}"
  )
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
endif ()

source_group("Include" FILES ${freekill_HEADERS})

target_sources(FreeKill PRIVATE ${freekill_SRCS})
target_precompile_headers(FreeKill PRIVATE "pch.h")
target_link_libraries(FreeKill PRIVATE
  ${LUA_LIB}
  ${SQLITE3_LIB}
  ${CRYPTO_LIB}
  ${READLINE_LIB}
  ${FKP_LIB}
  Qt6::Qml
  Qt6::Gui
  Qt6::Widgets
  Qt6::Network
  Qt6::Multimedia
)
