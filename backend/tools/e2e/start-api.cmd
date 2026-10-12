@echo off
rem Starts the API on the usual https://localhost:7056 with the same safe
rem overrides the end-to-end script uses: OTP codes go to the console, the
rem SMTP password is disabled so nothing can be sent, the webhook token is a
rem test value, and rate limits are raised. Environment variables beat user
rem secrets for this process only; your secrets are not changed.
rem
rem   tools\e2e\start-api.cmd            (from backend\)
cd /d "%~dp0..\..\src\SmartMoney.Api"
set "Email__Host= "
set "Email__Password=disabled-for-test"
set "Webhooks__CuelinksToken=local-test-token"
set "Payouts__Provider=Manual"
set "Payouts__FlatFee=10"
set "RateLimiting__AuthRequestsPerMinute=500"
set "RateLimiting__OtpRequestsPerTenMinutes=100"
set "RateLimiting__WithdrawalRequestsPerTenMinutes=500"
dotnet run --launch-profile https
