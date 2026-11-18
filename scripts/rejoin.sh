#!/usr/bin/env bash
# Brings a crashed former primary back and re-adds it as a fresh secondary (reseeded).
# Usage: scripts/rejoin.sh sql2
source "$(dirname "$0")/lib.sh"
NODE="${1:?usage: rejoin.sh <sql1|sql2|sql3>}"

PRIMARY=""
for n in "${NODES[@]}"; do
  [[ "$n" == "$NODE" ]] && continue
  is_running "$n" && [[ "$(local_role "$n")" == "PRIMARY" ]] && PRIMARY="$n"
done
[[ -n "$PRIMARY" ]] || die "no other replica is PRIMARY; refusing to reset $NODE"

step "Restarting $NODE (current primary is $PRIMARY)"
docker start "$NODE" >/dev/null
wait_for_sql "$NODE"
info "$NODE came back with local role: $(local_role "$NODE")  <- stale, it still thinks it owns ag1"

step "Rejoining $NODE as a fresh secondary of $PRIMARY"
sql_file "$NODE"    failover/07_reset_old_primary.sql
sql_file "$PRIMARY" failover/08_add_replica.sql -v NODE="$NODE"
sql_file "$NODE"    06_join_ag.sql
wait_db_state "$NODE" "SYNCHRONIZING|SYNCHRONIZED" 120
ok "$NODE role: $(local_role "$NODE")"
