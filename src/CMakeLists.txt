# SPDX-License-Identifier: GPL-3.0-or-later

file(GLOB SWIG_FILES "${PROJECT_SOURCE_DIR}/src/swig/*.i")
set(SWIG_SOURCE ${PROJECT_SOURCE_DIR}/src/swig/freekill.i)

add_custom_command(
  OUTPUT ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
  DEPENDS ${SWIG_FILES}
  COMMENT "Generating freekill-wrap.cxx"
  COMMAND swig -c++ -lua -Wall -o
    ${PROJECT_SOURCE_DIR}/src/swig/freekill-wrap.cxx
    ${SWIG_SOURCE}
)

set(freekill_EXESRCS
  "main.cpp"
)

set(freekill_SRCS
  # "main.cpp"
  "freekill.cpp"

  "core/player.cpp"
  "core/util.cpp"
  "core/c-wrapper.cpp"
  "core/packman.cpp"

  "client/client.cpp"
  "client/clientplayer.cpp"

  "network/server_socket.cpp"
  "network/client_socket.cpp"
  "network/router.cpp"

  "server/server.cpp"

  "server/user/auth.cpp"
  "server/user/serverplayer.cpp"

  "server/room/roombase.cpp"
  "server/room/lobby.cpp"
  "server/room/room.cpp"

  "server/task/task_manager.cpp"
  "server/task/task.cpp"

  "server/gamelogic/roomthread.cpp"

  "server/cli/shell.cpp"

  "ui/qmlbackend.cpp"

  "swig/freekill-wrap.cxx"
)
set_source_files_properties(
  "swig/freekill-wrap.cxx" PROPERTIES GENERATED TRUE)

if (NOT DEFINED FK_SERVER_ONLY)
  list(APPEND freekill_SRCS
    "client/replayer.cpp"
    # "ui/mod.cpp"
  )

  # Spine 渲染器（版本无关接口 + 各版本后端；纯 C 运行时在下方按版本编译为静态库）
  set(SPINE_PLUGIN_SRCS
    "ui/spine/texture.cpp"
    "ui/spine/skeletonrenderer.cpp"
    "ui/spine/rendercmdscache.cpp"
    "ui/spine/skeletonanimationfbo.cpp"
    "ui/spine/spineevent.cpp"
    "ui/spine/spineregister.cpp"
    "ui/spine/spineversion.cpp"
    "ui/spine/spinebackend_factory.cpp"
    "ui/spine/spinebackend_21.cpp"
    "ui/spine/spinebackend_34.cpp"
    "ui/spine/spinebackend_35.cpp"
    "ui/spine/spinebackend_36.cpp"
    "ui/spine/spinebackend_37.cpp"
    "ui/spine/spinebackend_38.cpp"
    "ui/spine/spinebackend_40.cpp"
    "ui/spine/spinebackend_41.cpp"
    "ui/spine/spinebackend_42.cpp"
  )
  list(APPEND freekill_SRCS ${SPINE_PLUGIN_SRCS})

  # spine-c 头文件中使用了 `slots` 作为字段名，与 Qt 关键字宏冲突，
  # 必须对这些文件关闭 Qt 关键字（代码已用 Q_SIGNALS/Q_EMIT 编写）。
  set_source_files_properties(${SPINE_PLUGIN_SRCS} PROPERTIES
    COMPILE_DEFINITIONS QT_NO_KEYWORDS
    SKIP_PRECOMPILE_HEADERS ON
  )

  include_directories("${PROJECT_SOURCE_DIR}/src/ui/spine")

  # SkeletonAnimation.qml 资源打进主程序（避免静态库资源需 Q_INIT_RESOURCE 的问题）
  set_property(TARGET FreeKill PROPERTY AUTORCC ON)
  list(APPEND freekill_EXESRCS "${PROJECT_SOURCE_DIR}/src/ui/spine/resource.qrc")

  # 多版本 spine-c 运行时（源码已按版本重命名符号，互不冲突）
  # 支持 2.1 / 3.4~3.8 / 4.0~4.2，供版本自动/显式分发使用
  set(SPINE_RUNTIME_VERSIONS 21 34 35 36 37 38 40 41 42)
  foreach(SPINE_VER IN LISTS SPINE_RUNTIME_VERSIONS)
    file(GLOB SPINE_VER_SRCS
      "${PROJECT_SOURCE_DIR}/src/spine-versions/spine-c-${SPINE_VER}/src/spine/*.c")
    add_library(spine${SPINE_VER} STATIC ${SPINE_VER_SRCS})
    # BEFORE：确保优先搜索本版本头文件，而不是旧的 src/spine-c/include
    target_include_directories(spine${SPINE_VER} BEFORE PRIVATE
      "${PROJECT_SOURCE_DIR}/src/spine-versions/spine-c-${SPINE_VER}/include")
    set_target_properties(spine${SPINE_VER} PROPERTIES
      C_STANDARD 11
      C_EXTENSIONS ON)
    # 旧版 C 代码告警较多，降级为不报错
    if(MSVC)
      target_compile_options(spine${SPINE_VER} PRIVATE /W0)
    else()
      target_compile_options(spine${SPINE_VER} PRIVATE -w)
    endif()
    # 后端 .cpp 只包含对应版本的 <spine/spine.h>，按文件指定 include 路径
    set_source_files_properties(
      "${PROJECT_SOURCE_DIR}/src/ui/spine/spinebackend_${SPINE_VER}.cpp"
      PROPERTIES INCLUDE_DIRECTORIES
      "${PROJECT_SOURCE_DIR}/src/spine-versions/spine-c-${SPINE_VER}/include")
    list(APPEND SPINE_LIBS spine${SPINE_VER})
  endforeach()
endif ()

set(QT_LIB Qt6::Network)

if (NOT DEFINED FK_SERVER_ONLY)
  list(APPEND QT_LIB
    Qt6::Qml
    Qt6::Quick
    Qt6::Gui
    Qt6::Widgets
    Qt6::Multimedia
    Qt6::QuickControls2
    Qt6::Concurrent
    Qt6::OpenGL
  )
endif()

if (WIN32)
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/win/lua54.dll)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/win/sqlite3.dll)
  set(CRYPTO_LIB OpenSSL::Crypto)
  set(GIT_LIB ${PROJECT_SOURCE_DIR}/lib/win/libgit2.dll)
  set(app_icon_resource_windows "${PROJECT_SOURCE_DIR}/image/icon.rc")
  list(APPEND freekill_EXESRCS ${app_icon_resource_windows})
elseif (ANDROID)
  if (DEFINED ENV{FK_ANDROID_SSL_DIR})
    set(SSL_DIR $ENV{FK_ANDROID_SSL_DIR})
    message(STATUS "Using SSL libraries from environment variable: ${SSL_DIR}")
    set(CRYPTO_LIB ${SSL_DIR}/libcrypto_3.so)
    set(SSL_LIB ${SSL_DIR}/libssl_3.so)
    set(GIT_LIB ${SSL_DIR}/libgit2.so)
  else ()
    set(CRYPTO_LIB ${PROJECT_SOURCE_DIR}/lib/android/libcrypto.so)
    set(SSL_LIB ${PROJECT_SOURCE_DIR}/lib/android/libssl.so)
    set(GIT_LIB ${PROJECT_SOURCE_DIR}/lib/android/libgit2.so)
    set(SSH_LIB ${PROJECT_SOURCE_DIR}/lib/android/libssh2.so)
  endif ()
  set(LUA_LIB ${PROJECT_SOURCE_DIR}/lib/android/liblua54.so)
  set(SQLITE3_LIB ${PROJECT_SOURCE_DIR}/lib/android/libsqlite3.so)

  set_target_properties(FreeKill PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR ${PROJECT_SOURCE_DIR}/android
    QT_ANDROID_EXTRA_LIBS "${LUA_LIB};${SQLITE3_LIB};${CRYPTO_LIB};${SSL_LIB};${GIT_LIB};${SSH_LIB}"
  )
  list(REMOVE_ITEM QT_LIB Qt6::QuickControls2)
elseif (IOS)
  set(LUA_LIB Lua::Lua)
  set(SQLITE3_LIB SQLite::SQLite3)
  set(CRYPTO_LIB OpenSSL::Crypto)
  find_package(libgit2 CONFIG REQUIRED)
  set(GIT_LIB libgit2::libgit2)
elseif (APPLE)
  set(LUA_LIB Lua::Lua)
  set(SQLITE3_LIB SQLite::SQLite3)
  set(CRYPTO_LIB OpenSSL::Crypto)
  find_package(libgit2 CONFIG REQUIRED)
  set(GIT_LIB libgit2::libgit2)
else ()
  set(LUA_LIB lua5.4)
  set(SQLITE3_LIB sqlite3)
  set(CRYPTO_LIB OpenSSL::Crypto)
  set(READLINE_LIB readline)
  set(GIT_LIB git2)
endif ()

add_library(libFreeKill STATIC ${freekill_SRCS})
target_precompile_headers(libFreeKill PRIVATE "pch.h")
target_link_libraries(libFreeKill PRIVATE
  ${LUA_LIB}
  ${SQLITE3_LIB}
  ${CRYPTO_LIB}
  ${SSL_LIB}
  ${READLINE_LIB}
  ${QT_LIB}
  ${SSH_LIB}
  ${GIT_LIB}
  ${IDBFS_LIB}
  ${JEMALLOC_LIBRARIES}
  ${SPINE_LIBS}
)

if (${CMAKE_BUILD_TYPE}0 STREQUAL "Debug0")
  target_compile_definitions(libFreeKill PRIVATE QT_QML_DEBUG)
endif ()

target_sources(FreeKill PRIVATE ${freekill_EXESRCS})
target_link_libraries(FreeKill PRIVATE
  libFreeKill
)

install(TARGETS FreeKill DESTINATION usr/bin)
install(DIRECTORY
  ${PROJECT_SOURCE_DIR}/audio
  ${PROJECT_SOURCE_DIR}/fonts
  ${PROJECT_SOURCE_DIR}/image
  ${PROJECT_SOURCE_DIR}/lua
  ${PROJECT_SOURCE_DIR}/Fk
  ${PROJECT_SOURCE_DIR}/server
  ${PROJECT_SOURCE_DIR}/client
  DESTINATION usr/share/FreeKill
)
install(DIRECTORY
  ${PROJECT_SOURCE_DIR}/packages/standard
  ${PROJECT_SOURCE_DIR}/packages/standard_cards
  ${PROJECT_SOURCE_DIR}/packages/test
  ${PROJECT_SOURCE_DIR}/packages/maneuvering
  DESTINATION usr/share/FreeKill/packages
)
install(FILES
  ${PROJECT_SOURCE_DIR}/fk_ver
  DESTINATION usr/share/FreeKill
)
install(FILES
  ${PROJECT_SOURCE_DIR}/packages/init.sql
  DESTINATION usr/share/FreeKill/packages
)
install(FILES
  ${PROJECT_SOURCE_DIR}/image/icon.png
  DESTINATION usr/share/icons
  RENAME FreeKill.png
)
install(FILES
  ${PROJECT_SOURCE_DIR}/freekill.desktop
  DESTINATION usr/share/applications
)

if (NOT DEFINED FK_SERVER_ONLY)
  install(FILES
    ${CMAKE_BINARY_DIR}/zh_CN.qm
    ${CMAKE_BINARY_DIR}/en_US.qm
    ${CMAKE_BINARY_DIR}/vi_VN.qm
    DESTINATION usr/share/FreeKill
  )
endif()

if(CPACK_GENERATOR STREQUAL "AppImage")
  install(CODE "
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink
                usr/share/icons/FreeKill.png
                \${CMAKE_INSTALL_PREFIX}/FreeKill.png
    )
  ")

  qt_generate_deploy_qml_app_script(
    TARGET FreeKill
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
  )
  install(SCRIPT ${deploy_script})

  set(CPACK_PACKAGE_ICON FreeKill)
  include(CPack)
endif()
