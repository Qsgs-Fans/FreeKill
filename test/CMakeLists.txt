find_package(Qt6 REQUIRED COMPONENTS Test)

set (TEST_LIB
  libFreeKill
  ${QT_LIB}
  Qt6::Test
)

qt_add_executable(Test test.cpp)

target_link_libraries(Test PRIVATE ${TEST_LIB})

add_test(NAME mytest COMMAND Test)
