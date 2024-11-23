find_package(Qt6 REQUIRED COMPONENTS Test)

set (TEST_LIB
  libFreeKill
  Qt6::Network
  Qt6::Test
  OpenSSL::Crypto
)

set (GUILESS_TEST_SRCS
  main.cpp
  # core/test_lua.cpp
  network/test_socket.cpp
  server/globals.cpp
  server/test_login.cpp
  server/test_create_room.cpp
  server/test_scheduler.cpp
)

qt_add_executable(TestWithoutGui ${GUILESS_TEST_SRCS})
target_precompile_headers(TestWithoutGui PRIVATE pch.h)
target_link_libraries(TestWithoutGui PRIVATE ${TEST_LIB})
add_test(
  NAME "tests without gui"
  COMMAND TestWithoutGui
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)
