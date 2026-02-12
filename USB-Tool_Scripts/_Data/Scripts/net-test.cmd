@echo off

title Network Test Script

:loop

echo %DATE% %TIME% >> net-test.log
echo: >> net-test.log

echo Pinging Router...
echo:

echo WIFI >> net-test.log
ping 192.168.1.1 >> net-test.log
echo: >> net-test.log

echo Pinging 8.8.8.8...
echo:

echo INTERNET >> net-test.log
ping 8.8.8.8 >> net-test.log
echo: >> net-test.log

echo Pinging Google.com...
rem echo:

echo DNS >> net-test.log
ping google.com >> net-test.log
echo: >> net-test.log

echo ---------------------------------------------------- >> net-test.log
echo: >> net-test.log

timeout 30
echo:

goto :loop