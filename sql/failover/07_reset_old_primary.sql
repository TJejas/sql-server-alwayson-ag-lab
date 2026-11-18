-- REJOIN 1/3 | Run on: the recovered old primary
-- It comes back believing it is still PRIMARY of ag1. Take its copy of the AG offline, drop it,
-- and drop the diverged database. (In production you would first back up that database to
-- salvage any transactions that never reached the new primary.)
:on error exit
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM sys.availability_groups WHERE name = 'ag1')
BEGIN
    BEGIN TRY ALTER AVAILABILITY GROUP [ag1] OFFLINE; END TRY BEGIN CATCH END CATCH;
    DROP AVAILABILITY GROUP [ag1];
END
GO
IF DB_ID('SalesDB') IS NOT NULL
BEGIN
    IF DATABASEPROPERTYEX('SalesDB', 'Status') = 'ONLINE'
        ALTER DATABASE SalesDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SalesDB;
END
PRINT CONCAT(@@SERVERNAME, ': stale ag1 and SalesDB removed');
