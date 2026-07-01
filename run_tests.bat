@echo off
setlocal

cd /d "%~dp0"
npm run verify:all
exit /b %ERRORLEVEL%
