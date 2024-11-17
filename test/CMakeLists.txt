find_package(Qt6 REQUIRED COMPONENTS Test)

set (TEST_LIB
  libFreeKill
  ${QT_LIB}
  Qt6::Test
)

qt_add_executable(TestSocket network/test_socket.cpp)
target_link_libraries(TestSocket PRIVATE ${TEST_LIB})
add_test(NAME "socket tests" COMMAND TestSocket)

qt_add_executable(TestServer server/test_server.cpp)
target_link_libraries(TestServer PRIVATE ${TEST_LIB})
add_test(NAME "server tests" COMMAND TestServer)
