#!/usr/bin/env bash
# Shows container state, each replica's local role, and full AG health from the primary.
source "$(dirname "$0")/lib.sh"

step "Containers"
for n in "${NODES[@]}"; do
  if is_running "$n"; then
    info "$n: running | role=$(local_role "$n") | $DB=$(db_state "$n") | rows=$(row_count "$n")"
  else
    info "$n: STOPPED"
  fi
done

p="$(current_primary)"
if [[ -n "$p" ]]; then
  step "AG health as seen by primary $p"
  sql_file "$p" 08_ag_health.sql
else
  step "No running PRIMARY replica found"
fi
