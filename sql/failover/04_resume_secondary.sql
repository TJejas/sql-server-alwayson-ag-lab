-- FAILOVER 4/5 (planned) or 2/2 (forced) | Run on: every replica except the new primary
-- Bring the replica back as a SECONDARY of the new primary and resume data movement.
-- After a role change the new primary suspends data movement on each secondary once that
-- secondary connects to it ("failover from partner"). That can happen a few seconds AFTER we
-- issue RESUME, so we keep resuming until data movement has stayed active for 5 seconds.
:on error exit
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM sys.dm_hadr_availability_replica_states
           WHERE is_local = 1 AND role_desc <> 'SECONDARY')
    ALTER AVAILABILITY GROUP [ag1] SET (ROLE = SECONDARY);
GO
DECLARE @i int = 0, @stable int = 0, @suspended bit, @state nvarchar(60);
WHILE @i < 60 AND @stable < 5
BEGIN
    SELECT @suspended = is_suspended, @state = synchronization_state_desc
    FROM sys.dm_hadr_database_replica_states
    WHERE is_local = 1 AND database_id = DB_ID('SalesDB');

    IF @suspended = 1
    BEGIN
        ALTER DATABASE [SalesDB] SET HADR RESUME;
        SET @stable = 0;
    END
    ELSE IF @state IN ('SYNCHRONIZING', 'SYNCHRONIZED')
        SET @stable += 1;

    WAITFOR DELAY '00:00:01';
    SET @i += 1;
END
IF @stable < 5
    THROW 50001, 'Data movement did not resume within 60 seconds', 1;
PRINT CONCAT(@@SERVERNAME, ': SECONDARY, data movement running');
