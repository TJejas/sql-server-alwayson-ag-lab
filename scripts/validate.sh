#!/usr/bin/env bash
# End-to-end validation of replication and failover. Assumes scripts/setup.sh has run.
#   1. write on sql1 -> rows appear on sql2 and sql3
#   2. secondaries reject writes
#   3. planned (zero-data-loss) failover sql1 -> sql2, write on sql2, verify everywhere
#   4. crash sql2 (docker kill), forced failover to sql3, write on sql3, verify on sql1
#   5. restart sql2, rejoin it as secondary, verify it caught up
#   6. planned failback to sql1, final consistency check on all 3 nodes
source "$(dirname "$0")/lib.sh"
D="$(dirname "$0")"
START=$(date +%s)

[[ "$(current_primary)" == "sql1" ]] || die "expected sql1 to be primary; run scripts/teardown.sh && scripts/setup.sh"

step "TEST 1: replication sql1 -> sql2, sql3"
base=$(row_count sql1)
insert_orders sql1 100 "test1-sql1"
expected=$((base + 100))
wait_rows sql2 "$expected"; wait_rows sql3 "$expected"

step "TEST 2: secondaries are read-only"
for n in sql2 sql3; do
  if sql_exec "$n" "INSERT $DB.dbo.Orders (CustomerName, Amount) VALUES (N'should-fail', 1);" >/dev/null 2>&1; then
    die "$n accepted a write while SECONDARY"
  fi
  ok "$n rejected the write (read-only secondary)"
done

step "TEST 3: planned failover sql1 -> sql2 (no data loss)"
bash "$D/planned-failover.sh" sql2
[[ "$(current_primary)" == "sql2" ]] || die "sql2 did not become primary"
wait_rows sql2 "$expected"
insert_orders sql2 50 "test3-sql2"
expected=$((expected + 50))
wait_rows sql1 "$expected"; wait_rows sql3 "$expected"

step "TEST 4: unplanned outage. Kill primary sql2, force failover to sql3"
bash "$D/forced-failover.sh" sql3
[[ "$(current_primary)" == "sql3" ]] || die "sql3 did not become primary"
survived=$(row_count sql3)
info "rows before crash: $expected, rows on new primary: $survived, lost: $((expected - survived))"
expected=$survived
insert_orders sql3 25 "test4-sql3"
expected=$((expected + 25))
wait_rows sql1 "$expected"

step "TEST 5: bring sql2 back and rejoin it as secondary"
bash "$D/rejoin.sh" sql2
wait_rows sql2 "$expected"

step "TEST 6: planned failback to sql1 and final consistency check"
bash "$D/planned-failover.sh" sql1
for n in "${NODES[@]}"; do wait_rows "$n" "$expected"; done
sql_exec sql1 "SELECT WrittenOn AS written_on_primary, COUNT(*) AS rows FROM $DB.dbo.Orders GROUP BY WrittenOn ORDER BY WrittenOn;"
bash "$D/status.sh"

printf '\n\033[1;32mALL TESTS PASSED\033[0m in %ss\n' "$(( $(date +%s) - START ))"
