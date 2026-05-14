:: Build ONNX Runtime as a static library (Windows, cmd.exe).
::
:: Usage:
::   scripts\build_static.bat [/config <Debug|Release|RelWithDebInfo>]
::                            [/build_dir <path>]
::                            [/parallel [N]]
::
:: Defaults:
::   /config     Release
::   /build_dir  build\Windows
::
:: Example (RelWithDebInfo):
::   scripts\build_static.bat /config RelWithDebInfo

@echo off
setlocal EnableDelayedExpansion

set "ROOT_DIR=%~dp0.."
set "CONFIG=Release"
set "BUILD_DIR=%ROOT_DIR%\build\Windows"
set "PARALLEL_ARG=--parallel"

:: ---------- parse arguments ----------
:parse_loop
if "%~1"=="" goto :done_parsing
if /I "%~1"=="/config" (
    set "CONFIG=%~2"
    shift & shift & goto :parse_loop
)
if /I "%~1"=="/build_dir" (
    set "BUILD_DIR=%~2"
    shift & shift & goto :parse_loop
)
if /I "%~1"=="/parallel" (
    :: check if next arg is a number
    set "NEXT=%~2"
    if "!NEXT!" neq "" (
        echo !NEXT!| findstr /r "^[0-9][0-9]*$" >nul 2>&1
        if not errorlevel 1 (
            set "PARALLEL_ARG=--parallel !NEXT!"
            shift & shift & goto :parse_loop
        )
    )
    set "PARALLEL_ARG=--parallel"
    shift & goto :parse_loop
)
echo Unknown option: %~1 >&2
echo Supported options: /config /build_dir /parallel >&2
exit /b 1

:done_parsing

:: ---------- locate Python ----------
where python >nul 2>&1
if errorlevel 1 (
    echo ERROR: python not found in PATH. >&2
    exit /b 1
)

echo ====================================================================
echo   Building ONNX Runtime as a static library
echo   Config     : %CONFIG%
echo   Build dir  : %BUILD_DIR%
echo ====================================================================

python "%ROOT_DIR%\tools\ci_build\build.py" ^
    --build_dir "%BUILD_DIR%" ^
    --config %CONFIG% ^
    --update ^
    --build ^
    --skip_tests ^
    %PARALLEL_ARG% ^
    --cmake_extra_defines ^
        CMAKE_POSITION_INDEPENDENT_CODE=ON ^
        onnxruntime_BUILD_UNIT_TESTS=OFF ^
        CMAKE_DISABLE_FIND_PACKAGE_Protobuf=ON ^
        CMAKE_DISABLE_FIND_PACKAGE_protobuf=ON

if errorlevel 1 (
    echo Build FAILED. >&2
    exit /b 1
)

echo.
echo ====================================================================
echo   Build complete.
echo   Static libraries are in: %BUILD_DIR%\%CONFIG%\%CONFIG%\
echo   Key artifacts:
echo     onnxruntime.lib
echo     onnxruntime_common.lib
echo   Public headers: %ROOT_DIR%\include\onnxruntime\
echo ====================================================================
endlocal
