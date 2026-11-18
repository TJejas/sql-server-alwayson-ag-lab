-- STEP 5b | Run on: sql2, sql3
-- A secondary must explicitly JOIN the AG that the primary defined.
-- GRANT CREATE ANY DATABASE is required for automatic seeding to create the DB here.
:on error exit
SET NOCOUNT ON;
USE master;

IF NOT EXISTS (SELECT 1 FROM sys.availability_groups WHERE name = 'ag1')
    ALTER AVAILABILITY GROUP [ag1] JOIN WITH (CLUSTER_TYPE = NONE);

ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;

PRINT CONCAT(@@SERVERNAME, ': joined ag1');
