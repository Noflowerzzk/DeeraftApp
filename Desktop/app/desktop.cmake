set(DEERAFT_APP_DIR "${CMAKE_CURRENT_LIST_DIR}")
find_package(Qt6 REQUIRED COMPONENTS Quick QuickWidgets QuickControls2 WebSockets)
find_package(OpenSSL REQUIRED)
set(DEERAFT_COMPAT_TESTS ON CACHE BOOL "Compatibility regression tests" FORCE)
add_subdirectory("${DEERAFT_APP_DIR}/compat" "${CMAKE_BINARY_DIR}/deeraft-compat")
target_sources(Launcher_logic PRIVATE
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
