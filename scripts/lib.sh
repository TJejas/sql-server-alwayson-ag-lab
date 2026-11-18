#!/usr/bin/env bash
# Shared helpers for the lab scripts. Sourced, not executed.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # stop Git Bash on Windows from rewriting /opt/... paths

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$ROOT/.env" ]]; then
  echo "Missing .env. Copy .env.example to .env and set the passwords." >&2; exit 1
fi
set -a; source <(tr -d '\r' < "$ROOT/.env"); set +a

NODES=(sql1 sql2 sql3)
AG=ag1
DB=SalesDB
SQLCMD=/opt/mssql-tools18/bin/sqlcmd

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m[OK]\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

# sql_file <node> <file under sql/> [-v NAME=value ...]
sql_file() {
  local node=$1 file=$2; shift 2
  docker exec "$node" $SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -C -b -W -i "/scripts/$file" "$@" \
    | tr -d '\r' | sed 's/^/  /'
}

# sql_exec <node> "<T-SQL>"   (prints output)
sql_exec() {
  docker exec "$1" $SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -C -b -W -Q "SET NOCOUNT ON; $2" \
    | tr -d '\r' | sed 's/^/  /'
}

# sql_scalar <node> "<T-SQL>"  (prints a single value, no headers)
sql_scalar() {
  docker exec "$1" $SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -C -b -h -1 -y 8000 -Q "SET NOCOUNT ON; $2" \
    | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
}

is_running() { [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]; }

wait_for_sql() {
  local n i
  for n in "$@"; do
    for i in $(seq 1 60); do
      if docker exec "$n" $SQLCMD -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT 1" >/dev/null 2>&1; then
        ok "$n is accepting connections"; continue 2
      fi
      sleep 2
    done
    die "$n did not come up"
  done
}

# Local role of a replica: PRIMARY, SECONDARY, RESOLVING, or empty
local_role() {
  sql_scalar "$1" "SELECT role_desc FROM sys.dm_hadr_availability_replica_states WHERE is_local = 1;" 2>/dev/null || true
}

current_primary() {
  local n
  for n in "${NODES[@]}"; do
    is_running "$n" || continue
    [[ "$(local_role "$n")" == "PRIMARY" ]] && { echo "$n"; return; }
  done
}

# Local sync state of SalesDB on a replica: SYNCHRONIZED, SYNCHRONIZING, NOT SYNCHRONIZING ...
db_state() {
  sql_scalar "$1" "SELECT synchronization_state_desc FROM sys.dm_hadr_database_replica_states
                   WHERE is_local = 1 AND database_id = DB_ID('$DB');" 2>/dev/null || true
}

# wait_db_state <node> <state1|state2> [timeout_s]
wait_db_state() {
  local node=$1 want=$2 timeout=${3:-90} i s
  for i in $(seq 1 "$timeout"); do
    s="$(db_state "$node")"
    if [[ "|$want|" == *"|$s|"* ]]; then ok "$node: $DB is $s"; return 0; fi
    sleep 1
  done
  die "$node: $DB is '${s:-missing}', expected $want after ${timeout}s"
}

row_count() { sql_scalar "$1" "SELECT COUNT(*) FROM $DB.dbo.Orders;" 2>/dev/null || echo "?"; }

# wait_rows <node> <expected> [timeout_s]
wait_rows() {
  local node=$1 want=$2 timeout=${3:-60} i c
  for i in $(seq 1 "$timeout"); do
    c="$(row_count "$node")"
    if [[ "$c" == "$want" ]]; then ok "$node sees $c rows"; return 0; fi
    sleep 1
  done
  die "$node sees $c rows, expected $want"
}

insert_orders() {   # insert_orders <node> <how many> <customer label>
  sql_exec "$1" "INSERT $DB.dbo.Orders (CustomerName, Amount)
                 SELECT TOP ($2) N'$3', CAST(ABS(CHECKSUM(NEWID())) % 50000 AS decimal(10,2)) / 100
                 FROM sys.all_objects;" >/dev/null
}
