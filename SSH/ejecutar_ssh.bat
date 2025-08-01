@echo off
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File ""%~dp0enable_ssh_complete.ps1""' -Verb RunAs"
