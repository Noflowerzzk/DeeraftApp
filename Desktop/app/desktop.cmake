set(DEERAFT_APP_DIR "${CMAKE_CURRENT_LIST_DIR}")
find_package(Qt6 REQUIRED COMPONENTS Quick QuickWidgets QuickControls2 WebSockets)
find_package(OpenSSL REQUIRED)
set(QM_BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
set(QM_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("${DEERAFT_APP_DIR}/vendor/QmlMaterial" "${CMAKE_BINARY_DIR}/qmlmaterial")
target_link_libraries(Launcher_logic qml_materialplugin)
set(DEERAFT_COMPAT_TESTS ON CACHE BOOL "Compatibility regression tests" FORCE)
add_subdirectory("${DEERAFT_APP_DIR}/compat" "${CMAKE_BINARY_DIR}/deeraft-compat")
target_sources(Launcher_logic PRIVATE
    "${DEERAFT_APP_DIR}/DesktopInstances.cpp"
    "${DEERAFT_APP_DIR}/DesktopWindow.cpp" "${DEERAFT_APP_DIR}/DesktopWindow.h"
    "${DEERAFT_APP_DIR}/library/DesktopLibrary.cpp" "${DEERAFT_APP_DIR}/library/DesktopLibrary.h"
    "${DEERAFT_APP_DIR}/DesktopBridge.cpp" "${DEERAFT_APP_DIR}/DesktopBridge.h"
    "${DEERAFT_APP_DIR}/DesktopShell.cpp" "${DEERAFT_APP_DIR}/DesktopShell.h"
    "${DEERAFT_APP_DIR}/community/CommunityClient.cpp" "${DEERAFT_APP_DIR}/community/CommunityClient.h"
    "${DEERAFT_APP_DIR}/accounts/ExternalAuthService.cpp" "${DEERAFT_APP_DIR}/accounts/ExternalAuthService.h"
    "${DEERAFT_APP_DIR}/accounts/ExternalAccountController.cpp" "${DEERAFT_APP_DIR}/accounts/ExternalAccountController.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/minecraft/auth/ExternalAuthStep.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/minecraft/auth/ExternalAuthStep.h"
    "${DEERAFT_APP_DIR}/deeraft.qrc")
target_sources(Launcher_logic PRIVATE "${DEERAFT_APP_DIR}/download/DownloadSources.cpp" "${DEERAFT_APP_DIR}/download/DownloadSources.h")
target_sources(Launcher_logic PRIVATE "${DEERAFT_APP_DIR}/webview/LivePlayer.cpp" "${DEERAFT_APP_DIR}/webview/LivePlayer.h")
target_include_directories(Launcher_logic PRIVATE "${DEERAFT_APP_DIR}/webview/vendor")
target_include_directories(Launcher_logic PUBLIC "${DEERAFT_APP_DIR}")
target_link_libraries(Launcher_logic Qt6::Quick Qt6::QuickWidgets Qt6::QuickControls2 Qt6::WebSockets OpenSSL::Crypto deeraft_compat)
if(WIN32)
    target_link_libraries(Launcher_logic crypt32 ole32 shlwapi version)
endif()
set_target_properties(${Launcher_Name} PROPERTIES OUTPUT_NAME "DeeraftApp")

if(BUILD_TESTING)
 find_package(Qt6 REQUIRED COMPONENTS Test)
 add_executable(deeraft_library_tests "${DEERAFT_APP_DIR}/library/tests/DesktopLibraryTest.cpp")
 set_target_properties(deeraft_library_tests PROPERTIES AUTOMOC ON)
 target_link_libraries(deeraft_library_tests PRIVATE Launcher_logic Qt6::Test)
 file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/test-temp")
 add_test(NAME deeraft_library_tests COMMAND deeraft_library_tests)
 set_tests_properties(deeraft_library_tests PROPERTIES ENVIRONMENT "TEMP=${CMAKE_BINARY_DIR}/test-temp;TMP=${CMAKE_BINARY_DIR}/test-temp")
endif()

# Reduce peak compiler memory for the generated meta-object aggregation only.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
 set_source_files_properties("${CMAKE_CURRENT_BINARY_DIR}/Launcher_logic_autogen/mocs_compilation.cpp" PROPERTIES COMPILE_OPTIONS "-O1")
endif()
