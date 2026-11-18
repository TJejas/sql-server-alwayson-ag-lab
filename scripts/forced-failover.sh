#!/usr/bin/env bash
# Simulates an unplanned outage: kills the primary container, then forces a secondary to
# take over and evicts the dead replica.  Usage: scripts/forced-failover.sh sql3
source "$(dirname "$0")/lib.sh"
TARGET="${1:?usage: forced-failover.sh <sql1|sql2|sql3>}"

OLD="$(current_primary)"
[[ -n "$OLD" ]] || die "no running primary found"
[[ "$OLD" != "$TARGET" ]] || die "$TARGET is already the primary"

step "Disaster: killing primary $OLD (docker kill = power loss, no clean shutdown)"
docker kill "$OLD" >/dev/null
ok "$OLD is down"

OTHERS=()
for n in "${NODES[@]}"; do
  [[ "$n" == "$TARGET" || "$n" == "$OLD" ]] && continue
  is_running "$n" && OTHERS+=("$n")
done

step "Forced failover to $TARGET"
# Detach the surviving secondaries from the dead primary first, otherwise they keep
# waiting on their old database connection to it instead of following the new primary.
for n in "${OTHERS[@]}"; do sql_file "$n" failover/02_offline.sql; done
sql_file "$TARGET" failover/03_promote_target.sql
sql_file "$TARGET" failover/06_remove_failed_replica.sql -v NODE="$OLD"
for n in "${OTHERS[@]}"; do sql_file "$n" failover/04_resume_secondary.sql; done
ok "primary is now $(current_primary). Bring $OLD back with: scripts/rejoin.sh $OLD"
