rem Parameters

set VERSION=%1
set BLD_NUM=%2
set BUILD_NUMBER=%VERSION%-%BLD_NUM%

set VOLTRON_BRANCH=%3
set MANIFEST=%4
set LICENSE=%5
set ARCHITECTURE=%6
set SRC_DIR_PREFIX=%7

rem Name directory "v" to save a few vital characters - otherwise some
rem InstallShield merge module unpacks to a directory with too long a name

if exist v goto voltron_exists
    git clone --branch %VOLTRON_BRANCH% git@github.com:couchbase/voltron.git v || goto error
:voltron_exists

cd v
git reset --hard
git clean -dfx
git fetch
git checkout    %VOLTRON_BRANCH% || goto error
git pull origin %VOLTRON_BRANCH% || goto error

:package_win
echo ======== package =============================
ruby server-win.rb %WORKSPACE%\couchbase\install 5.10.4 couchbase_server %BUILD_NUMBER% %LICENSE% %ARCHITECTURE% %SRC_DIR_PREFIX%  || goto error

set PKG_SRC_DIR=%WORKSPACE%\v\couchbase_server\%VERSION%\%BLD_NUM%
set PKG_SRC_NAME=couchbase_server-%LICENSE%-windows-%ARCHITECTURE%-%BUILD_NUMBER%.exe
set PKG_DEST_NAME=couchbase-server-%LICENSE%_%BUILD_NUMBER%-windows_%ARCHITECTURE%.exe

copy %PKG_SRC_DIR%\%PKG_SRC_NAME% %WORKSPACE%\%PKG_DEST_NAME%

echo ========== creating trigger.properties ==============
cd %WORKSPACE%
echo PLATFORM=windows> trigger.properties
echo INSTALLER_FILENAME=%PKG_DEST_NAME%>> trigger.properties
