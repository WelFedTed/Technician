@echo off

rem Updated: 29-12-2020

title Creating Hash Files

rem Pass all arguments to and launch hash_create.ps1
for %%x in (%*) do (
rem	powershell.exe -NoProfile -ExecutionPolicy bypass -Command "& '%~dpn0.ps1' "%%x""

	rem Check if argument is file or folder
	for /f "tokens=1,2 delims=d" %%A in ("-%~a1") do if "%%B" neq "" (
		rem echo %1 is a folder
		echo Recursively processing folder "%~n1"...
		for /d %%d in (%1\*) do (
			rem echo %%d
			start /wait /b cmd /k call "%~dpn0.bat" "%%d"
		)
		for %%f in (%1\*) do (
			rem echo %%f
			start /wait /b cmd /k call "%~dpn0.bat" "%%f"
		)
	) else if "%%A" neq "-" (
		rem echo %1 is a file
		py "%~dpn0.py" %%x
	) else (
		echo %1 does not exist
	)
	echo:
)

echo:
rem pause
exit