@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Estructura de Carpetas del Proyecto

:: Cambiar al directorio donde reside el script
cd /d "%~dp0"

:: Asegurar codificacion UTF-8
chcp 65001 >nul

:: Asegurar que las carpetas de cache interno y git esten ocultas
:: para que el comando 'tree' no las recorra innecesariamente (ej. shaders de Godot)
if exist ".godot" attrib +h ".godot" >nul 2>&1
if exist ".git" attrib +h ".git" >nul 2>&1

set "FILE_CARPETAS=estructura_carpetas.txt"
set "FILE_COMPLETO=estructura_completa.txt"

:: Modo por parametro de linea de comandos
if /i "%~1"=="/completo" goto ACCION_COMPLETO
if /i "%~1"=="/f" goto ACCION_COMPLETO
if /i "%~1"=="/carpetas" goto ACCION_CARPETAS
if /i "%~1"=="/c" goto ACCION_CARPETAS
if /i "%~1"=="/help" goto AYUDA
if /i "%~1"=="/?" goto AYUDA

:ACCION_CARPETAS
cls
echo ===============================================================================
echo       ESTRUCTURA DE CARPETAS Y SUBCARPETAS - SOLO DIRECTORIOS
echo ===============================================================================
echo Proyecto: %CD%
echo Fecha: %DATE% - %TIME%
echo ===============================================================================
echo.

:: Generar el reporte de solo carpetas en archivo de texto
echo =============================================================================== > "%FILE_CARPETAS%"
echo REPORTE DE ESTRUCTURA DE CARPETAS - SOLO DIRECTORIOS >> "%FILE_CARPETAS%"
echo Proyecto: %CD% >> "%FILE_CARPETAS%"
echo Fecha: %DATE% - %TIME% >> "%FILE_CARPETAS%"
echo =============================================================================== >> "%FILE_CARPETAS%"
echo. >> "%FILE_CARPETAS%"
tree /A >> "%FILE_CARPETAS%"
echo. >> "%FILE_CARPETAS%"
echo =============================================================================== >> "%FILE_CARPETAS%"

:: Mostrar en consola
tree /A

echo.
echo ===============================================================================
echo [OK] Estructura guardada con exito en: %FILE_CARPETAS%
echo ===============================================================================
echo.

if /i "%~1"=="/carpetas" exit /b 0
if /i "%~1"=="/c" exit /b 0

:MENU_OPCIONES
echo Que deseas hacer ahora?
echo   [1] Abrir '%FILE_CARPETAS%' en Bloc de Notas
echo   [2] Ver y exportar arbol COMPLETO con archivos (%FILE_COMPLETO%)
echo   [3] Salir
echo.
set "OPC="
set /p "OPC=Selecciona una opcion [1-3, Default: 1]: "

if "%OPC%"=="" set "OPC=1"
if "%OPC%"=="1" (
    start notepad.exe "%FILE_CARPETAS%"
    goto SALIR
)
if "%OPC%"=="2" goto ACCION_COMPLETO
if "%OPC%"=="3" goto SALIR

echo Opcion no reconocida.
echo.
goto MENU_OPCIONES

:ACCION_COMPLETO
cls
echo ===============================================================================
echo       ESTRUCTURA COMPLETA - CARPETAS, SUBCARPETAS Y ARCHIVOS
echo ===============================================================================
echo Proyecto: %CD%
echo Fecha: %DATE% - %TIME%
echo ===============================================================================
echo.

:: Generar el reporte con archivos en archivo de texto
echo =============================================================================== > "%FILE_COMPLETO%"
echo REPORTE COMPLETO DE ESTRUCTURA - CARPETAS Y ARCHIVOS >> "%FILE_COMPLETO%"
echo Proyecto: %CD% >> "%FILE_COMPLETO%"
echo Fecha: %DATE% - %TIME% >> "%FILE_COMPLETO%"
echo =============================================================================== >> "%FILE_COMPLETO%"
echo. >> "%FILE_COMPLETO%"
tree /F /A >> "%FILE_COMPLETO%"
echo. >> "%FILE_COMPLETO%"
echo =============================================================================== >> "%FILE_COMPLETO%"

:: Mostrar en pantalla
tree /F /A

echo.
echo ===============================================================================
echo [OK] Estructura completa guardada en: %FILE_COMPLETO%
echo ===============================================================================
echo.

if /i "%~1"=="/completo" exit /b 0
if /i "%~1"=="/f" exit /b 0

set "ABRIR="
set /p "ABRIR=Deseas abrir '%FILE_COMPLETO%' en el Bloc de Notas? [S/N, Default: S]: "
if /i "%ABRIR%"=="" set "ABRIR=S"
if /i "%ABRIR%"=="S" start notepad.exe "%FILE_COMPLETO%"
goto SALIR

:AYUDA
echo.
echo ===============================================================================
echo  USO DEL SCRIPT:
echo ===============================================================================
echo   listar_carpetas.bat            - Modo interactivo: muestra arbol y crea reporte
echo   listar_carpetas.bat /carpetas  - Genera solo arbol de carpetas sin pausar
echo   listar_carpetas.bat /completo  - Genera arbol con archivos sin pausar
echo ===============================================================================
echo.
exit /b 0

:SALIR
echo.
echo Finalizado.
exit /b 0
