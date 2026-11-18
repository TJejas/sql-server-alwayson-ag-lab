-- REJOIN 2/3 | Run on: the current PRIMARY | var: NODE
-- Re-add the recovered server as an asynchronous, readable secondary. Automatic seeding will
-- copy SalesDB to it as soon as it joins (REJOIN 3/3 = 06_join_ag.sql on NODE).
:on error exit
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM sys.availability_replicas WHERE replica_server_name = N'$(NODE)')
    ALTER AVAILABILITY GROUP [ag1] ADD REPLICA ON N'$(NODE)' WITH (
        ENDPOINT_URL = N'tcp://$(NODE):5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        SEEDING_MODE = AUTOMATIC,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
    );
PRINT CONCAT(@@SERVERNAME, ': $(NODE) added back to ag1');
