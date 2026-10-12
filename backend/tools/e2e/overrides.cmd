@echo off
rem Scenario overrides for start-api-real.cmd. Edit and restart between
rem scenarios. Environment variables beat user secrets for this process only.
rem
rem Currently: no scenario, the owner's normal settings (Manual provider,
rem 60-minute tokens, real rate limits). Only the Cuelinks simulator token is
rem set so tools\affiliate-simulator works without a real one.
rem
rem For the Fake provider scenarios (see docs\WITHDRAWAL_MANUAL_TEST.md
rem section 8) add, for example:
rem   set "Payouts__Provider=Fake"
rem   set "Payouts__Fake__Behavior=Pending"      (or Success, Reject, TemporaryFailure)
rem   set "Payouts__WorkerIntervalSeconds=10"
rem   set "Payouts__ReconcileAfterMinutes=1"
rem   set "Payouts__FlatFee=10"
rem   set "Jwt__ExpirationMinutes=2"             (token refresh test)
set "Webhooks__CuelinksToken=local-test-token"
