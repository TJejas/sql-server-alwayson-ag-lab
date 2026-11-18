-- STEP 5a | Run on: sql1 (initial primary)
-- CLUSTER_TYPE = NONE: no Windows Failover Cluster or Pacemaker. Good for read scale-out and
-- DR labs. There is no automatic failover, so every failover is a manual T-SQL operation.
-- ASYNCHRONOUS_COMMIT: the primary commits without waiting for secondaries to harden the log.
-- Lowest latency, but a crash of the primary can lose the transactions not yet shipped (RPO > 0).
:on error exit
SET NOCOUNT ON;
USE master;

IF NOT EXISTS (SELECT 1 FROM sys.availability_groups WHERE name = 'ag1')
BEGIN
    CREATE AVAILABILITY GROUP [ag1]
        WITH (CLUSTER_TYPE = NONE)
        FOR REPLICA ON
        N'sql1' WITH (
            ENDPOINT_URL = N'tcp://sql1:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            FAILOVER_MODE = MANUAL,
            SEEDING_MODE = AUTOMATIC,                   -- secondaries get the DB over the endpoint, no manual restore
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)    -- secondaries are readable
        ),
        N'sql2' WITH (
            ENDPOINT_URL = N'tcp://sql2:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            FAILOVER_MODE = MANUAL,
            SEEDING_MODE = AUTOMATIC,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
        ),
        N'sql3' WITH (
            ENDPOINT_URL = N'tcp://sql3:5022',
            AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
            FAILOVER_MODE = MANUAL,
            SEEDING_MODE = AUTOMATIC,
            SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
        );

    -- Lets automatic seeding create databases on this replica if it ever becomes a secondary.
    ALTER AVAILABILITY GROUP [ag1] GRANT CREATE ANY DATABASE;
END

PRINT CONCAT(@@SERVERNAME, ': availability group ag1 created');
