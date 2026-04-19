@echo off
chcp 65001 >nul
REM Simple CPU Assembler Installer

echo ========================================
echo Simple CPU Assembler Installer
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

echo [ERROR] Python not found!
echo.
set /p MANUAL_PATH="Enter full path to python.exe (or press Enter to exit): "

if "%MANUAL_PATH%"=="" (
    echo Installation cancelled.
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

echo [INFO] Installing Simple CPU Assembler...
echo.

cd /d "%~dp0"
%PYTHON_CMD% -m pip install -e .

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Installation failed!
    echo.
    echo Try running as Administrator if permission denied.
    pause
    exit /b 1
)

echo.
echo ========================================
echo [SUCCESS] Installation complete!
echo ========================================
echo.
pause
