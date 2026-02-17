@echo off
setlocal enabledelayedexpansion

cd /d "G:\WorkingDATA\art.kubus\art.kubus"

REM Run flutter analyze
echo === COMMAND 1: flutter analyze ===
flutter analyze 2>&1 > analyze_output.txt
set ANALYZE_EXIT=%ERRORLEVEL%
echo.
echo === EXIT CODE: %ANALYZE_EXIT% ===
type analyze_output.txt
echo.

REM Run flutter test
echo === COMMAND 2: flutter test ===
flutter test 2>&1 > test_output.txt
set TEST_EXIT=%ERRORLEVEL%
echo.
echo === EXIT CODE: %TEST_EXIT% ===
type test_output.txt
echo.

REM Run flutter build web
echo === COMMAND 3: flutter build web --release ===
flutter build web --release 2>&1 > build_output.txt
set BUILD_EXIT=%ERRORLEVEL%
echo.
echo === EXIT CODE: %BUILD_EXIT% ===
type build_output.txt
echo.

REM Summary
echo.
echo ========== SUMMARY ==========
echo ANALYZE EXIT CODE: %ANALYZE_EXIT%
echo TEST EXIT CODE: %TEST_EXIT%
echo BUILD EXIT CODE: %BUILD_EXIT%
echo =============================
