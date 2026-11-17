@echo off

rem Updated: 29-12-2020

title Creating Hash Files

rem Pass all arguments to and launch hash_create.ps1
for %%x in (%*) do (
rem	powershell.exe -NoProfile -ExecutionPolicy bypass -Command "& '%~dpn0.ps1' "%%x""

	rem Check if argument is file or folder (each one in turn: %%x, not %1, which is always the first)
	for /f "tokens=1,2 delims=d" %%A in ("-%%~ax") do if "%%B" neq "" (
		rem echo %%x is a folder
		echo Recursively processing folder "%%~nx"...
		for /d %%d in ("%%~x\*") do (
			rem echo %%d
			start /wait /b cmd /k call "%~f0" "%%d"
		)
		for %%f in ("%%~x\*") do (
			rem echo %%f
			start /wait /b cmd /k call "%~f0" "%%f"
		)
	) else if "%%A" neq "-" (
		rem echo %%x is a file
		py "%~dpn0.py" "%%~x"
	) else (
		echo %%x does not exist
	)
	echo:
)

echo:
rem pause
exit