@echo off
setlocal

:: Set paths
set "FRP_DIR=%~dp0frp"
set "ARK_DIR=%~dp0ark"

:: Start frpc in a new window
start "FRP Client" cmd /k ""%FRP_DIR%\frpc.exe" -c "%FRP_DIR%\frpc.toml""

:: Start Ark Dedicated Server in a new window 
start "Ark Server" cmd /k ""%ARK_DIR%\ShooterGame\Binaries\Win64\ArkAscendedServer.exe" TheIsland_WP?SessionName=MyServerBehindNAT?"