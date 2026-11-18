-- PLANNED FAILOVER 2/5 | Run on: current PRIMARY, then every NON-participating secondary
-- With CLUSTER_TYPE = NONE there is no cluster manager to coordinate the role change, so we
-- take the AG offline on every replica except the target. The primary stops accepting writes,
-- so the (already SYNCHRONIZED) target cannot fall behind.
:on error exit
SET NOCOUNT ON;
ALTER AVAILABILITY GROUP [ag1] OFFLINE;
PRINT CONCAT(@@SERVERNAME, ': ag1 taken OFFLINE');
