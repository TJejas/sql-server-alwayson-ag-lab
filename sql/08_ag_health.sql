-- STEP 7 | Run on: the PRIMARY (it sees the state of every replica; a secondary only sees itself)
SET NOCOUNT ON;

PRINT '--- Replicas ---';
SELECT ar.replica_server_name                         AS replica,
       rs.role_desc                                   AS role,
       ar.availability_mode_desc                      AS commit_mode,
       ar.failover_mode_desc                          AS failover,
       rs.connected_state_desc                        AS connected,
       rs.synchronization_health_desc                 AS health
FROM sys.availability_replicas ar
JOIN sys.dm_hadr_availability_replica_states rs ON rs.replica_id = ar.replica_id
ORDER BY ar.replica_server_name;

PRINT '--- Databases (queues in KB; 0 = fully caught up) ---';
SELECT ar.replica_server_name                         AS replica,
       DB_NAME(drs.database_id)                       AS db,
       drs.synchronization_state_desc                 AS sync_state,
       drs.is_suspended                               AS suspended,
       ISNULL(drs.log_send_queue_size, 0)             AS log_send_queue_kb,  -- not yet sent to secondary
       ISNULL(drs.redo_queue_size, 0)                 AS redo_queue_kb,      -- received, not yet replayed
       drs.last_commit_time                           AS last_commit_time
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON ar.replica_id = drs.replica_id
ORDER BY ar.replica_server_name;
