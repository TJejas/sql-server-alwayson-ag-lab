-- FAILOVER (planned 3/5, forced 1/2) | Run on: the TARGET secondary
-- CLUSTER_TYPE = NONE only supports FORCE_FAILOVER_ALLOW_DATA_LOSS.
--  * Planned: the target was SYNCHRONIZED and the old primary is demoted, so no data is lost.
--  * Forced (primary crashed): whatever the async secondary had not received is lost.
:on error exit
SET NOCOUNT ON;
ALTER AVAILABILITY GROUP [ag1] FORCE_FAILOVER_ALLOW_DATA_LOSS;
PRINT CONCAT(@@SERVERNAME, ': is now PRIMARY');
