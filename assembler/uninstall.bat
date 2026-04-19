@echo off
chcp 65001 >nul
REM Simple CPU Assembler Uninstaller

echo ========================================
echo Simple CPU Assembler Uninstaller
echo ========================================
echo.

REM Try to find Python command
set PYTHON_CMD=

py --version >nul 2>&1
if %errorlevel% == 0 (
    set PYTHON_CMD=py
    goto :found_python
)

python --version >nul 2>&1
if %errorlevel% == 0 (
    set PYTHON_CMD=python
    goto :found_python
)

python3 --version >nul 2>&1
if %errorlevel% == 0 (
    set PYTHON_CMD=python3
    goto :found_python
)

echo [WARNING] Python not found automatically.
set /p MANUAL_PATH="Enter full path to python.exe (or press Enter to exit): "

if "%MANUAL_PATH%"=="" (
    echo Uninstallation cancelled.
    pause
    exit /b 1
)

if not exist "%MANUAL_PATH%" (
    echo [ERROR] File not found: %MANUAL_PATH%
    pause
    exit /b 1
)

set PYTHON_CMD=%MANUAL_PATH%

:found_python
echo [INFO] Using Python: %PYTHON_CMD%
%PYTHON_CMD% --version
echo.

echo [INFO] Uninstalling Simple CPU Assembler...
%PYTHON_CMD% -m pip uninstall simple-cpu-assembler -y

echo.
echo ========================================
echo [SUCCESS] Uninstallation complete!
echo ========================================
echo.
pause
