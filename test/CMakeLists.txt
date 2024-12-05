find_package(Qt6 REQUIRED COMPONENTS Test)

set (TEST_LIB
  libFreeKill
  Qt6::Network
  Qt6::Test
  OpenSSL::Crypto
)

#[[set (GUILESS_TEST_SRCS
  main.cpp
  # core/test_lua.cpp
  network/test_socket.cpp
  server/globals.cpp
  server/test_login.cpp
  server/test_create_room.cpp
  server/test_scheduler.cpp
)]]

set (GUILESS_TEST_SRCS
  main.cpp
  server/globals.cpp
)

#[[qt_add_executable(TestWithoutGui ${GUILESS_TEST_SRCS})
target_precompile_headers(TestWithoutGui PRIVATE pch.h)
target_link_libraries(TestWithoutGui PRIVATE ${TEST_LIB})
add_test(
  NAME "tests without gui"
  COMMAND TestWithoutGui
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)]]

qt_add_executable(TestSocket server/globals.cpp network/test_socket.cpp)
target_precompile_headers(TestSocket PRIVATE pch.h)
target_link_libraries(TestSocket PRIVATE ${TEST_LIB})
add_test(
  NAME "socket test"
  COMMAND TestSocket
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

qt_add_executable(TestLogin server/globals.cpp server/test_login.cpp)
target_precompile_headers(TestLogin REUSE_FROM TestSocket)
target_link_libraries(TestLogin PRIVATE ${TEST_LIB})
add_test(
  NAME "login test"
  COMMAND TestLogin
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

qt_add_executable(TestRoom server/globals.cpp server/test_create_room.cpp)
target_precompile_headers(TestRoom REUSE_FROM TestSocket)
target_link_libraries(TestRoom PRIVATE ${TEST_LIB})
add_test(
  NAME "room test"
  COMMAND TestRoom
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

qt_add_executable(TestScheduler server/globals.cpp server/test_scheduler.cpp)
target_precompile_headers(TestScheduler REUSE_FROM TestSocket)
target_link_libraries(TestScheduler PRIVATE ${TEST_LIB})
add_test(
  NAME "scheduler test"
  COMMAND TestScheduler
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

qt_add_executable(TestLuaCore lua_core_test.cpp)
target_precompile_headers(TestLuaCore REUSE_FROM TestSocket)
target_link_libraries(TestLuaCore PRIVATE ${TEST_LIB})
add_test(
  NAME "lua core test"
  COMMAND TestLuaCore
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

qt_add_executable(TestLuaRoom lua_room_test.cpp)
target_precompile_headers(TestLuaRoom REUSE_FROM TestSocket)
target_link_libraries(TestLuaRoom PRIVATE ${TEST_LIB})
add_test(
  NAME "lua room test"
  COMMAND TestLuaRoom
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)
