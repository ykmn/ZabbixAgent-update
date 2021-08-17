@echo off
:: Zabbix Agent update with simple file copy and manual service management
:: Roman Ermakov <r.ermakov@emg.fm>
:: v2.0 2021-08-02 Second release on Windows Batch
setlocal EnableDelayedExpansion
:: UPDATE  HERE TO LATEST VERSION!
set ZabbixAgentVersion=5.4.3

set ZabbixAgentRelease=%ZabbixAgentVersion:~0,3%
:: Let default config path be in %ProgramData% C:\ProgramData\zabbix\zabbix_agentd.conf
set configFile=C:\ProgramData\zabbix\zabbix_agentd.conf

if [%1]==[] goto:usage
set i=%1
set i=%i:~0,2%
if NOT %i%==\\ goto:usage

if NOT [%2]==[--default] goto:start
if [%2]==[--default] set DEFAULT=DEFAULT

:start
:: get local path
cd /D "%~dp0"
set HOSTNAME=%1
:: replacing \\
set HOSTNAME=%HOSTNAME:\\=%


:process
echo.
echo.
echo [92m--------------------------------------------------------------------- [0m
echo [92mProcessing \\%HOSTNAME%. [0m
echo.
echo [93mDisconnecting admin share. [0m
net use \\%HOSTNAME%\c$ /DELETE >NUL

:: Detect OS architecture
reg Query "\\%HOSTNAME%\HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OSArchitecture=32-bit|| set OSArchitecture=64-bit
echo Detected %OSArchitecture% OS


:: download ZIP
:downloadzip
if %OSArchitecture%==32-bit ( 
    set agentFilename=zabbix_agent-%ZabbixAgentVersion%-windows-i386-openssl.zip
) else (
    set agentFilename=zabbix_agent-%ZabbixAgentVersion%-windows-amd64-openssl.zip
)

echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mDownloading %agentFilename%. [0m
if exist .\%agentFilename% (
    echo File %agentFilename% was already downloaded earlier.
) else (
    powershell -NoProfile -ExecutionPolicy unrestricted -Command "Invoke-WebRequest https://cdn.zabbix.com/zabbix/binaries/stable/%ZabbixAgentRelease%/%ZabbixAgentVersion%/%agentFilename% -OutFile %agentFilename%"
::  https://cdn.zabbix.com/zabbix/binaries/stable/5.4/5.4.3/zabbix_agent-5.4.3-windows-amd64-openssl.zip
    echo File %agentFilename% downloaded
)
    :: Unzipping archive
if NOT exist .\%ZabbixAgentVersion%\%OSArchitecture% (
::    7z x -y -o.\%ZabbixAgentVersion% %agentFilename% 
    powershell -NoProfile -ExecutionPolicy unrestricted -Command "Expand-Archive -Path %agentFilename% -DestinationPath .\%ZabbixAgentVersion%\%OSArchitecture% -Force"
    echo File %agentFilename% unpacked to %ZabbixAgentVersion%\%OSArchitecture%
) else (
    echo Folder %ZabbixAgentVersion%\%OSArchitecture% already exists.
)




:: searching for Zabbix Agent service
echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mSearching for Zabbix Agent service. [0m
sc \\%HOSTNAME% query "Zabbix Agent" >NUL
if ERRORLEVEL 1060 echo Zabbix Agent service is not found && goto:asktocontinue
for /f "tokens=1* delims=:" %%a in ('sc \\%HOSTNAME% query "Zabbix Agent" ^| find "STATE"') do (
    echo Service found, state: %%~b
)

:: parsing config and exe files location at "C:\Program Files\Zabbix Agent\zabbix_agentd.exe" --config "C:\ProgramData\zabbix\zabbix_agentd.conf"
echo [93m--------------------------------------------------------------------- [0m
echo [93mQuerying Zabbix Agent service path. [0m
for /f "tokens=1* delims=:" %%a in ('sc \\%HOSTNAME% qc "Zabbix Agent" ^| find "BINARY_PATH_NAME"') do (
::    echo %%~a
    echo Found service path: %%~b
::    echo %%~c
    set "commandline=%%~b"
)

:: searching for EXE part
:: to delete everything after the string '--config' first we need  delete '--config' and everything before it
SET configFile=%commandline:* --config =%
:: now remove this from the original string
CALL SET exeFile=%%commandline:%configFile%=%%
:: remove " and --config
set exeFile=%exeFile:"=%
set exeFile=%exeFile: --config=%
:: trim 1st and last space
set exeFile=%exeFile:~1,-1%
echo EXE file is %exeFile%

:: searching for config part
set "configFile=%commandline%"
:: get part after --config
set "configFile=%configFile:* --config =%"
:: remove "
set configFile=%configFile:"=%
:: trim 1st space
set "configFile=%configFile:~0%"
echo Config file is %configFile%


:: Stopping existing Zabbix Agent Servive
:stopservice
echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mStopping Zabbix Agent Service. [0m
sc \\%HOSTNAME% stop "Zabbix Agent"


:: Removing Zabbix Agent service
:removeservice
echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mRemoving Zabbix Agent service: [0m

:: Backup config file
:askbackupconfig
if DEFINED DEFAULT goto:skipbackupconfig
set choice=
set /p choice=Do you want to backup Zabbix Agent configuration? (Y/N) 
if '%choice%'=='y' goto:dobackupconfig
if '%choice%'=='Y' goto:dobackupconfig
if '%choice%'=='n' goto:skipbackupconfig
if '%choice%'=='N' goto:skipbackupconfig
if '%choice%'=='q' goto:quit
if '%choice%'=='Q' goto:quit
echo "%choice%" is not valid, try again
echo.
goto:askbackupconfig

:dobackupconfig
xcopy "\\%HOSTNAME%\c$\%configFile:~3%" "\\%HOSTNAME%\c$\%configFile:~3%.bak" /-Y
:: without leading C:\
echo.
:skipbackupconfig


:: Remove service
:askremoveservice
if DEFINED DEFAULT goto:dodelservice
set choice=
set /p choice=[91mDo you want to remove Zabbix Agent service? (Y/N)[0m
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='y' goto:dodelservice
if '%choice%'=='Y' goto:dodelservice
if '%choice%'=='n' goto:skipdelservice
if '%choice%'=='N' goto:skipdelservice
if '%choice%'=='q' goto:quit
if '%choice%'=='Q' goto:quit
echo "%choice%" is not valid, try again
echo.
goto:askremoveservice

:dodelservice
sc \\%HOSTNAME% delete "Zabbix Agent"
:skipdelservice

:: Ask for config location
:askconfiglocation
echo.
if DEFINED DEFAULT goto:newconfiglocation
set choice=
set /p choice=[92mDo you want to store configuration file in the default location C:\ProgramData\Zabbix\zabbix_agentd.conf ? (Y/N)[0m
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='y' goto:newconfiglocation
if '%choice%'=='Y' goto:newconfiglocation
if '%choice%'=='n' goto:oldconfiglocation
if '%choice%'=='N' goto:oldconfiglocation
if '%choice%'=='q' goto:quit
if '%choice%'=='Q' goto:quit
echo "%choice%" is not valid, try again
goto:askconfiglocation

:newconfiglocation
set configFile=C:\ProgramData\Zabbix\zabbix_agentd.conf
echo.
:oldconfiglocation
echo Configuration file location: %configFile%




:: Remove files
:askremovefiles
if DEFINED DEFAULT goto:dodelfiles
echo.
set choice=
set /p choice=[91mDo you want to remove old Zabbix Agent files? (Y/N)[0m
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='y' goto:dodelfiles
if '%choice%'=='Y' goto:dodelfiles
if '%choice%'=='n' goto:skipdelfiles
if '%choice%'=='N' goto:skipdelfiles
if '%choice%'=='q' goto:quit
if '%choice%'=='Q' goto:quit
echo "%choice%" is not valid, try again
echo.
goto:askremovefiles

:dodelfiles
if DEFINED DEFAULT (
    rd /S /Q "\\%HOSTNAME%\c$\Program Files\Zabbix Agent"
) else (
    rd /S "\\%HOSTNAME%\c$\Program Files\Zabbix Agent"
)
:skipdelfiles

:: Continue
:asktocontinue
if DEFINED DEFAULT goto:docontinue
echo.
set choice=
set /p choice=[92mReady to install Zabbix Agent. Continue? (Y/N)[0m
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='y' goto:docontinue
if '%choice%'=='Y' goto:docontinue
if '%choice%'=='n' goto:done
if '%choice%'=='N' goto:done
if '%choice%'=='q' goto:quit
if '%choice%'=='Q' goto:quit
echo "%choice%" is not valid, try again
echo.
goto:asktocontinue
:docontinue


:: Copy files
:copyfiles
echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mCopying new Zabbix Agent files: [0m
mkdir "\\%HOSTNAME%\c$\Program Files\Zabbix Agent"
xcopy .\%ZabbixAgentVersion%\%OSArchitecture%\bin\*.exe "\\%HOSTNAME%\c$\Program Files\Zabbix Agent" /F
echo.
:: Removing drive name from config file and copy config file
echo [93mCopying configuration file to %configFile%: [0m
if DEFINED DEFAULT (
    xcopy .\zabbix_agentd.conf "\\%HOSTNAME%\c$\%configFile:~3%*" /F /Y
) else (
    xcopy .\zabbix_agentd.conf "\\%HOSTNAME%\c$\%configFile:~3%*" /F
)
:: trailing * supress xcopy's question about file or directory
echo.

:: Creating Zabbix Agent service
:createservice
echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mCreating Zabbix Agent service: [0m
echo Service executable path: "C:\Program Files\Zabbix Agent\zabbix_agentd.exe" --config "%configFile%"
sc \\%HOSTNAME% create "Zabbix Agent" binPath= "\"C:\Program Files\Zabbix Agent\zabbix_agentd.exe\" --config \"%configFile%\"" start= auto

:: Starting Zabbix Agent service
:startservice
echo.
echo.
echo [93m--------------------------------------------------------------------- [0m
echo [93mStarting Zabbix Agent service: [0m
if DEFINED DEFAULT goto:dostartservice
:askstartservice
set choice=
set /p choice=Do you want to start Zabbix Agent service now? (Y/N)
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='y' goto:dostartservice
if '%choice%'=='Y' goto:dostartservice
if '%choice%'=='n' goto:skipstartservice
if '%choice%'=='N' goto:skipstartservice
if '%choice%'=='q' goto:quit
if '%choice%'=='Q' goto:quit
echo "%choice%" is not valid, try again
echo.
goto:askstartservice
:dostartservice
sc \\%HOSTNAME% start "Zabbix Agent"
:skipstartservice
goto:done


:quit
echo [92m--------------------------------------------------------------------- [0m
echo [92mQuit! [0m
goto:eof

:done
echo [92m--------------------------------------------------------------------- [0m
echo [92mDone! [0m
goto:eof

:usage
echo update-agent.bat       2021.08.02 Version 2.0
echo Interactive tool for install, update or remove Zabbix Agent on remote Windows host.
echo.
echo [47m[30mUsage:[0m update-agent \\HOSTNAME [--default]
echo.
echo You need to have admin rights on remote host.
echo This script uses network services. If you want to upgrade Zabbix Agent on local machine
echo please restart this script elevated and use [93mupdate-agent \\localhost [0m
echo.
echo --default      if service found: removes old service and files without backup,
echo                                  installs new service with default location of config file 
echo                                  C:\ProgramData\Zabbix\zabbix_agentd.conf
echo                                  and starts service after installation.
echo.
