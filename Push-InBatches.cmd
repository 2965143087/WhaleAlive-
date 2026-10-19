@echo off
rem Run the batched push with ExecutionPolicy bypassed for this process only.
rem The machine policy is Restricted, so an unsigned .ps1 cannot run directly.
rem Usage: double-click this file, or run  .\Push-InBatches.cmd  in PowerShell.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Push-InBatches.ps1" %*
if errorlevel 1 (
    echo.
    echo [Push-InBatches] Not all commits were pushed.
    echo Re-run with the failing step number to resume, for example:
    echo     powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Push-InBatches.ps1" -StartStep 4
    pause
)
