-- PLANNED FAILOVER 5/5 | Run on: the NEW primary
-- Put the AG back into its normal configuration: every replica asynchronous, and commits
-- no longer wait for a synchronized secondary.
:on error exit
SET NOCOUNT ON;
ALTER AVAILABILITY GROUP [ag1] SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0);

DECLARE @r sysname, @sql nvarchar(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT replica_server_name FROM sys.availability_replicas
    WHERE availability_mode_desc <> 'ASYNCHRONOUS_COMMIT';
OPEN c; FETCH NEXT FROM c INTO @r;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER AVAILABILITY GROUP [ag1] MODIFY REPLICA ON N''' + @r
             + N''' WITH (AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT);';
    EXEC (@sql);
    FETCH NEXT FROM c INTO @r;
END
CLOSE c; DEALLOCATE c;
PRINT CONCAT(@@SERVERNAME, ': all replicas back to ASYNCHRONOUS_COMMIT');
