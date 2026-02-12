@echo off

title Emptying Recycle Bin...

powershell.exe -NoProfile -ExecutionPolicy bypass -Command "Clear-RecycleBin -force -ErrorAction:Ignore"

rem pause