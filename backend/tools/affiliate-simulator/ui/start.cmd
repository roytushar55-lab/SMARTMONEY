@echo off
rem Starts the affiliate simulator web tool on http://localhost:5290.
rem It needs the Cuelinks webhook token that the API was started with
rem (the Webhooks:CuelinksToken value). Set it first, in this window:
rem
rem   set SM_WEBHOOK_TOKEN=your-token
rem   tools\affiliate-simulator\ui\start.cmd          (from backend\)
rem
rem Optional: SM_SIM_TARGET (default https://localhost:7056), SM_SIM_PORT
rem (default 5290). It only talks to local addresses unless SM_SIM_ALLOW_REMOTE=1.
if not defined SM_WEBHOOK_TOKEN echo Warning: SM_WEBHOOK_TOKEN is not set; sending will be disabled.
node "%~dp0server.mjs"
