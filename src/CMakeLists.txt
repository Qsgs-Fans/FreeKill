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

if (WIN32)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/win/lua54.dll)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/win/sqlite3.dll)
elseif (ANDROID)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/android/liblua54.so)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/android/libsqlite3.so)
  set_target_properties(FreeKill PROPERTIES
    QT_ANDROID_EXTRA_LIBS "${LUA_LIB};${SQLITE3_LIB}"
  )
else ()
  set(LUA_LIB lua5.4)
  set(SQLITE3_LIB sqlite3)
endif ()

source_group("Include" FILES ${freekill_HEADERS})

target_sources(FreeKill PRIVATE ${freekill_SRCS})
target_precompile_headers(FreeKill PRIVATE "pch.h")
target_link_libraries(FreeKill PRIVATE
  ${LUA_LIB}
  ${SQLITE3_LIB}
  fkparse
  Qt6::Qml
  Qt6::Gui
  Qt6::Network
  #Qt6::Multimedia
  Qt6::Core5Compat
)
