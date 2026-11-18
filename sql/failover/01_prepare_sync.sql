-- PLANNED FAILOVER 1/5 | Run on: current PRIMARY | var: TARGET
-- With asynchronous commit, the target may be behind. For a zero-data-loss failover we
-- temporarily switch BOTH the primary and the target to SYNCHRONOUS_COMMIT (a commit is only
-- synchronous when both ends of the pair are), then require 1 synchronized secondary for every
-- commit, so nothing can commit on the primary that the target has not hardened.
:on error exit
SET NOCOUNT ON;
DECLARE @me sysname = @@SERVERNAME, @sql nvarchar(400);
SET @sql = N'ALTER AVAILABILITY GROUP [ag1] MODIFY REPLICA ON N''' + @me
         + N''' WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);';
EXEC (@sql);
GO
ALTER AVAILABILITY GROUP [ag1]
    MODIFY REPLICA ON N'$(TARGET)' WITH (AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
GO
ALTER AVAILABILITY GROUP [ag1]
    SET (REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 1);
GO
PRINT CONCAT(@@SERVERNAME, ' and $(TARGET) switched to SYNCHRONOUS_COMMIT');
