@echo off

title Have I Been Pwned

rem Opens Have I Been Pwned, to check whether an email address or phone number is in a known data breach (and
rem its Pwned Passwords page, haveibeenpwned.com/Passwords, for passwords)
rem in the default browser (a website, so it needs the internet)

echo Opening Have I Been Pwned...
start "" "https://haveibeenpwned.com/"
exit /b