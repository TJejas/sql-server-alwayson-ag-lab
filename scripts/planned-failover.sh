#!/usr/bin/env bash
# Zero-data-loss manual failover for a CLUSTER_TYPE = NONE AG, following Microsoft's documented
# read-scale AG procedure.  Usage: scripts/planned-failover.sh sql2
source "$(dirname "$0")/lib.sh"
TARGET="${1:?usage: planned-failover.sh <sql1|sql2|sql3>}"

OLD="$(current_primary)"
[[ -n "$OLD" ]] || die "no running primary found"
[[ "$OLD" != "$TARGET" ]] || die "$TARGET is already the primary"
OTHERS=()
for n in "${NODES[@]}"; do
  [[ "$n" == "$OLD" || "$n" == "$TARGET" ]] && continue
  is_running "$n" && OTHERS+=("$n")
done
step "Planned failover: $OLD -> $TARGET"

info "1/5 switch $OLD and $TARGET to synchronous commit, wait until $TARGET is SYNCHRONIZED"
sql_file "$OLD" failover/01_prepare_sync.sql -v TARGET="$TARGET"
wait_db_state "$TARGET" "SYNCHRONIZED" 60

info "2/5 take ag1 offline on $OLD ${OTHERS[*]:+and ${OTHERS[*]}}"
sql_file "$OLD" failover/02_offline.sql
for n in "${OTHERS[@]}"; do sql_file "$n" failover/02_offline.sql; done

info "3/5 promote $TARGET"
sql_file "$TARGET" failover/03_promote_target.sql

info "4/5 bring $OLD ${OTHERS[*]:+and ${OTHERS[*]} }back as secondaries"
for n in "$OLD" "${OTHERS[@]}"; do sql_file "$n" failover/04_resume_secondary.sql; done

info "5/5 return to asynchronous commit"
sql_file "$TARGET" failover/05_restore_async.sql

for n in "$OLD" "${OTHERS[@]}"; do wait_db_state "$n" "SYNCHRONIZING|SYNCHRONIZED" 60; done
ok "primary is now $(current_primary)"
