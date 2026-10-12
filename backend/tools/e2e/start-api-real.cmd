@echo off
rem Starts the API on https://localhost:7056 with the owner's REAL settings
rem (user secrets: real SMTP, real admin seed), plus whatever overrides
rem tools\e2e\overrides.cmd sets for the scenario under test. Registering a
rem user through this instance sends a real email.
rem
rem   tools\e2e\start-api-real.cmd        (from backend\)
cd /d "%~dp0..\..\src\SmartMoney.Api"
if exist "%~dp0overrides.cmd" call "%~dp0overrides.cmd"
dotnet run --launch-profile https
