@echo off
title Shorebird Android Releaser
echo ========================================================
echo               Shorebird Android Releaser (APK)
echo ========================================================
echo.
echo [1/3] Checking current Git status...
git status -s
echo.
echo --------------------------------------------------------
set /p confirm="Do you want to build and deploy this release APK? (Y/N): "
if /i "%confirm%" neq "Y" (
    echo.
    echo [!] Release build aborted by user.
    echo.
    pause
    exit /b
)

echo.
echo [2/3] Running Shorebird release...
echo.
call "C:\Users\HP\.shorebird\bin\shorebird.bat" release android --artifact apk
echo.
echo [3/3] Process finished.
echo ========================================================
pause
