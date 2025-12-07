@echo off
rem sim_isim.bat — run ISim with optional Tcl batch if present
setlocal

rem ========== CONFIG ==========
set XILINX=E:\XISE\14.7\ISE_DS
set TB=
set BUILD=build
set SIMDIR=sim
set LOGSDIR=logs
rem =================================

pushd "%~dp0" >nul

if not exist "%BUILD%\isim.prj" (
  echo ERROR: %BUILD%\isim.prj not found. Run build.bat first.
  popd
  exit /b 1
)

rem Auto-detect TB from sim\*_tb.vhd or sim\*tb*.vhd (filename without extension)
if "%TB%"=="" (
  set FOUND=
  for /f "delims=" %%f in ('dir /b "%SIMDIR%\*_tb.vhd" 2^>nul') do (
    set "TB=%%~nf"
    set FOUND=1
    goto :tb_found
  )
  for /f "delims=" %%f in ('dir /b "%SIMDIR%\*tb*.vhd" 2^>nul') do (
    set "TB=%%~nf"
    set FOUND=1
    goto :tb_found
  )
  if not defined FOUND (
    echo No testbench detected in %SIMDIR%. Please set TB variable in this script.
    popd
    exit /b 1
  )
)
:tb_found

echo Running fuse for testbench: %TB% ...
"%XILINX%\ISE\bin\nt\fuse.exe" -prj "%BUILD%\isim.prj" work.%TB% -o "%BUILD%\%TB%_isim.exe" > "%LOGSDIR%\fuse.log" 2>&1
if errorlevel 1 (
  echo ERROR: fuse linking failed. See logs\fuse.log
  type "%LOGSDIR%\fuse.log" | more
  popd
  exit /b 1
)

echo Fuse succeeded. Launching ISim GUI...

rem Check if Tcl batch script exists
if exist "scripts\isim_run.tcl" (
  "%BUILD%\%TB%_isim.exe" -gui -tclbatch scripts\isim_run.tcl
) else (
  echo WARNING: scripts\isim_run.tcl not found — launching GUI without Tcl script
  "%BUILD%\%TB%_isim.exe" -gui
)

popd
endlocal
