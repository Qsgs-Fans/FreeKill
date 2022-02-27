set(freekill_SRCS
    "main.cpp"
    "core/player.cpp"
    "core/global.cpp"
    "network/server_socket.cpp"
    "network/client_socket.cpp"
    "network/router.cpp"
    "server/server.cpp"
    "server/serverplayer.cpp"
    "server/room.cpp"
    "server/gamelogic.cpp"
    "client/client.cpp"
    "client/clientplayer.cpp"
    "ui/qmlbackend.cpp"
    "swig/freekill-wrap.cxx"
)

set(freekill_HEADERS
    "core/global.h"
    "core/player.h"
    "network/server_socket.h"
    "network/client_socket.h"
    "network/router.h"
    "server/server.h"
    "server/serverplayer.h"
    "server/room.h"
    "server/gamelogic.h"
    "client/client.h"
    "client/clientplayer.h"
    "ui/qmlbackend.h"
)

if (WIN32)
    set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/win/lua54.dll)
else ()
    set(LUA_LIB lua5.4)
endif ()

source_group("Include" FILES ${freekill_HEADERS})
add_executable(FreeKill ${freekill_SRCS})
target_link_libraries(FreeKill ${LUA_LIB} Qt5::Qml Qt5::Gui Qt5::Network Qt5::Multimedia)
add_custom_command(
    OUTPUT ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
    DEPENDS ${PROJECT_SOURCE_DIR}/src/swig/freekill.i
    COMMENT "Generating freekill-wrap.cxx"
    COMMAND swig -c++ -lua -Wall -o
        ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
        ${PROJECT_SOURCE_DIR}/src/swig/freekill.i
)
