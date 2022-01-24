qt5_add_resources(freekill_SRCS resources.qrc)
add_executable(freekill main.cpp ${freekill_SRCS})
target_link_libraries(freekill Qt5::Qml Qt5::Gui)

