-- Per-environment database hardening for SmartMoney on Azure PostgreSQL.
-- Run by provision.ps1, connected to the environment's database as the
-- server admin. Idempotent. Variables (psql -v): owner, app, db, admin.
-- Passwords come from the environment: SM_OWNER_PASSWORD, SM_APP_PASSWORD.
--
-- Result:
--   * schema "smartmoney" owned by the owner login; tables live there, not in public
--   * owner login (sm_<env>_owner): owns the tables; used only for migrations
--   * app login (sm_<env>_app): read/write rows only; no DDL, no TRUNCATE
--   * only the two logins of this environment may connect to this database
--   * search_path for both logins is "smartmoney"

\set ON_ERROR_STOP on
\getenv owner_pw SM_OWNER_PASSWORD
\getenv app_pw SM_APP_PASSWORD
\if :{?owner_pw}
\else
  \echo 'SM_OWNER_PASSWORD is not set'
  \quit 1
\endif
\if :{?app_pw}
\else
  \echo 'SM_APP_PASSWORD is not set'
  \quit 1
\endif

-- Logins (created once; password and attributes enforced on every run)
SELECT format('CREATE ROLE %I LOGIN', :'owner')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'owner') \gexec
SELECT format('CREATE ROLE %I LOGIN', :'app')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app') \gexec

SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L',
              :'owner', :'owner_pw') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L',
              :'app', :'app_pw') \gexec

-- The admin needs membership in the owner role to create its schema and
-- set its default privileges.
SELECT format('GRANT %I TO %I WITH INHERIT TRUE, SET TRUE', :'owner', :'admin') \gexec

-- Only this environment's logins may connect to this database.
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'db') \gexec
SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I, %I', :'db', :'owner', :'app') \gexec

-- Dedicated schema; nothing may be created in public.
SELECT format('CREATE SCHEMA IF NOT EXISTS smartmoney AUTHORIZATION %I', :'owner') \gexec
SELECT format('ALTER SCHEMA smartmoney OWNER TO %I', :'owner') \gexec
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA smartmoney FROM PUBLIC;
SELECT format('GRANT USAGE ON SCHEMA smartmoney TO %I', :'app') \gexec

-- Row access for the app login, on today's tables and on every table the
-- owner creates later (EF migrations run as the owner).
SELECT format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA smartmoney TO %I', :'app') \gexec
SELECT format('GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA smartmoney TO %I', :'app') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA smartmoney GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I',
              :'owner', :'app') \gexec
SELECT format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA smartmoney GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
              :'owner', :'app') \gexec

-- Unqualified table names resolve to smartmoney (the API's connection
-- string also sets Search Path=smartmoney).
SELECT format('ALTER ROLE %I IN DATABASE %I SET search_path = smartmoney', :'owner', :'db') \gexec
SELECT format('ALTER ROLE %I IN DATABASE %I SET search_path = smartmoney', :'app', :'db') \gexec

\echo Database :db ready: schema smartmoney, owner :owner, app :app
