@echo off
REM ===========================================================================
REM  Create Vivado project for exp7 (Loongson CPU)
REM ===========================================================================

REM Try to find vivado in PATH first
where vivado >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set VIVADO_CMD=vivado
) else (
    REM Vivado 2019.2 default installation path (use CALL for .bat wrapper)
    set "VIVADO_CMD=CALL D:\Xilinx\Vivado\2019.2\bin\vivado.bat"
)

echo [INFO] Creating Vivado project ...

%VIVADO_CMD% -source create_project.tcl -mode tcl -notrace

if %ERRORLEVEL% EQU 0 (
    echo [INFO] Project created successfully!
    echo [INFO] Project file: %CD%\project\loongson.xpr
) else (
    echo [ERROR] Failed to create project!
    echo [ERROR] Check: 1) Vivado installation path  2) create_project.tcl syntax
)

pause
