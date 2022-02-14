file(GLOB_RECURSE freekill_SRCS
    "*.cpp"
    "*.cxx"
)

file(GLOB_RECURSE freekill_HEADERS
    "*.h"
    "*.hpp"
)

# source_group("Include" FILES ${freekill_HEADERS})
add_executable(freekill ${freekill_SRCS} ${freekill_HEADERS})
target_link_libraries(freekill Qt5::Qml Qt5::Gui Qt5::Network Qt5::Multimedia)

