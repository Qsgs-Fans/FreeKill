find_package(Qt6 REQUIRED COMPONENTS Test)

set (TEST_LIB
  libFreeKill
  Qt6::Network
  Qt6::Qml
  Qt6::Gui
  Qt6::Widgets
  Qt6::Multimedia
  Qt6::QuickControls2
  Qt6::Test
)

qt_add_executable(TestSocket network/test_socket.cpp)
target_precompile_headers(TestSocket PRIVATE "pch.h")
target_link_libraries(TestSocket PRIVATE ${TEST_LIB})
add_test(NAME "socket tests" COMMAND TestSocket)

qt_add_executable(TestLogin server/test_login.cpp server/server_thread.cpp)
target_precompile_headers(TestLogin REUSE_FROM TestSocket)
target_link_libraries(TestLogin PRIVATE ${TEST_LIB})
add_test(NAME "login tests" COMMAND TestLogin)

qt_add_executable(TestRoom server/test_create_room.cpp server/server_thread.cpp)
target_precompile_headers(TestRoom REUSE_FROM TestSocket)
target_link_libraries(TestRoom PRIVATE ${TEST_LIB})
add_test(NAME "room creation tests" COMMAND TestRoom)

qt_add_executable(TestLuaCore core/test_lua.cpp)
target_precompile_headers(TestLuaCore REUSE_FROM TestSocket)
target_link_libraries(TestLuaCore PRIVATE ${TEST_LIB})
add_test(NAME "core lua tests" COMMAND TestLuaCore)
