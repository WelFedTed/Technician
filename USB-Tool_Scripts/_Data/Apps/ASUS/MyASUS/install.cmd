@echo off

title Install MyASUS

rem MyASUS only comes from the Microsoft Store (product 9N7R5S6B0ZZH), so there's nothing to keep on the
rem USB: this opens it in the Store app to install, or its Store page in the browser when this PC has no Store app
rem (on ASUS laptops it also needs the ASUS System Control Interface driver, from the model's support page)

reg query "HKCR\ms-windows-store" >nul 2>&1
if errorlevel 1 (
	echo This PC has no Microsoft Store app, so MyASUS's Store page will open in the browser.
	start "" "https://apps.microsoft.com/detail/9N7R5S6B0ZZH"
	exit /b
)
echo Opening MyASUS in the Microsoft Store...
start "" "ms-windows-store://pdp/?productid=9N7R5S6B0ZZH"
exit /b