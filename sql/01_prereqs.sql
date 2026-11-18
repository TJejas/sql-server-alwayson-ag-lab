-- STEP 2 | Run on: ALL replicas
-- Database master key: protects the private key of the certificate we create in step 3.
-- dbm_login / dbm_user: the principal that will OWN the endpoint certificate. When a remote
-- replica connects with that certificate, SQL Server maps it to dbm_login, which we grant
-- CONNECT on the endpoint in step 4.
:on error exit
SET NOCOUNT ON;
USE master;

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$(MASTER_KEY_PASSWORD)';

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbm_login')
    CREATE LOGIN dbm_login WITH PASSWORD = '$(DBM_LOGIN_PASSWORD)';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbm_user')
    CREATE USER dbm_user FOR LOGIN dbm_login;

-- The AlwaysOn_health Extended Events session is not started automatically on Linux.
ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE = ON);
IF NOT EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE name = 'AlwaysOn_health')
    ALTER EVENT SESSION AlwaysOn_health ON SERVER STATE = START;

PRINT CONCAT(@@SERVERNAME, ': master key, dbm_login and AlwaysOn_health ready');
