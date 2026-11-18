-- FORCED FAILOVER 2/2 | Run on: the NEW primary | var: NODE (the crashed old primary)
-- After a forced failover the old primary may hold transactions the new primary never received.
-- If it came back on its own it would still think it is PRIMARY (split-brain). Microsoft's
-- guidance for CLUSTER_TYPE = NONE is to evict it from the AG and re-add it later as a fresh
-- secondary.
:on error exit
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM sys.availability_replicas WHERE replica_server_name = N'$(NODE)')
    ALTER AVAILABILITY GROUP [ag1] REMOVE REPLICA ON N'$(NODE)';
PRINT CONCAT(@@SERVERNAME, ': removed failed replica $(NODE) from ag1');
