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

qt_add_executable(TestServer server/test_server.cpp)
target_precompile_headers(TestServer REUSE_FROM TestSocket)
target_link_libraries(TestServer PRIVATE ${TEST_LIB})
add_test(NAME "server tests" COMMAND TestServer)
