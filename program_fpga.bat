@echo off
rem ============================================================
rem program_fpga.bat — build‑to‑.bit must be done already.
rem This script will drive Xilinx iMPACT in batch mode to program
rem the FPGA (Spartan‑6) via JTAG with the generated .bit file.
rem ============================================================
setlocal

rem --- User settings (adjust if necessary) ---
set XILINX=E:\XISE\14.7\ISE_DS
set BITFILE=build\LCL_Project1_14041.bit
set LOGSDIR=logs

rem --- Check bitstream exists ---
if not exist "%BITFILE%" (
  echo ERROR: Bitstream file not found: "%BITFILE%"
  echo Please run build.bat first.
  exit /b 1
)

rem --- Create an iMPACT batch script on the fly ---
set SCRIPTFILE=%TEMP%\impact_auto.cmd
del /f /q "%SCRIPTFILE%" 2>nul

(
  echo setMode -bs
  echo setCable -p auto
  echo addDevice -p 1 -file "%CD%\%BITFILE%"
  echo program -p 1
  echo quit
) > "%SCRIPTFILE%"

echo Generated iMPACT commands:
type "%SCRIPTFILE%"

rem --- Run iMPACT in batch mode ---
echo Launching iMPACT ...
"%XILINX%\ISE\bin\nt\impact.exe" -batch "%SCRIPTFILE%"
if errorlevel 1 (
  echo ERROR: iMPACT failed. Check output above.
  del /f /q "%SCRIPTFILE%"
  exit /b 1
)

echo FPGA programming succeeded.

rem --- Cleanup ---
del /f /q "%SCRIPTFILE%"
popd 2>nul
endlocal
exit /b 0
