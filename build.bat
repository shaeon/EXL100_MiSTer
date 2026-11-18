@echo off
rem Compila EXL100 para MiSTer con Quartus 17.0 desde linea de comandos
set QUARTUS=C:\altera_lite\17.0\quartus\bin64
"%QUARTUS%\quartus_sh.exe" --flow compile EXL100 -c EXL100
if errorlevel 1 goto :error
for /f %%i in ('powershell -nologo -noprofile -command "Get-Date -Format yyyyMMdd"') do set DT=%%i
copy /y output_files\EXL100.rbf releases\EXL100_%DT%.rbf >nul
echo Hecho: releases\EXL100_%DT%.rbf
goto :eof
:error
echo Error de compilacion
exit /b 1
