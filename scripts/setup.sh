#!/usr/bin/env bash
# Builds the whole lab: 3 containers -> certificate trust -> endpoints -> AG -> SalesDB.
# Safe to re-run: every T-SQL step checks whether its object already exists.
source "$(dirname "$0")/lib.sh"
cd "$ROOT"

step "Step 1: start 3 SQL Server containers (hostnames sql1, sql2, sql3)"
docker compose up -d
wait_for_sql "${NODES[@]}"
for n in "${NODES[@]}"; do
  info "$n: @@SERVERNAME=$(sql_scalar "$n" "SELECT @@SERVERNAME;"), IsHadrEnabled=$(sql_scalar "$n" "SELECT SERVERPROPERTY('IsHadrEnabled');")"
done

step "Step 2: master key, endpoint login and AlwaysOn_health on every node"
for n in "${NODES[@]}"; do
  sql_file "$n" 01_prereqs.sql -v MASTER_KEY_PASSWORD="$MASTER_KEY_PASSWORD" DBM_LOGIN_PASSWORD="$DBM_LOGIN_PASSWORD"
done

step "Step 3: create the endpoint certificate on sql1 and copy it to sql2/sql3"
sql_file sql1 02_create_certificate.sql
CERT_HEX="$(sql_scalar sql1 "SELECT CONVERT(varchar(max), CERTENCODED(CERT_ID('dbm_certificate')), 1);")"
KEY_HEX="$(sql_scalar sql1 "SELECT CONVERT(varchar(max), CERTPRIVATEKEY(CERT_ID('dbm_certificate'), '$CERT_PASSWORD'), 1);")"
info "exported certificate (${#CERT_HEX} hex chars) and encrypted private key (${#KEY_HEX} hex chars)"
for n in sql2 sql3; do
  sql_file "$n" 03_import_certificate.sql -v CERT_HEX="$CERT_HEX" KEY_HEX="$KEY_HEX" CERT_PASSWORD="$CERT_PASSWORD"
done

step "Step 4: database mirroring endpoint on port 5022 on every node"
for n in "${NODES[@]}"; do sql_file "$n" 04_create_endpoint.sql; done

step "Step 5: create AG 'ag1' on sql1 (CLUSTER_TYPE = NONE, asynchronous commit), join sql2 and sql3"
sql_file sql1 05_create_ag.sql
for n in sql2 sql3; do sql_file "$n" 06_join_ag.sql; done

step "Step 6: create SalesDB on sql1, back it up, add it to the AG (automatic seeding)"
sql_file sql1 07_create_database.sql
for n in sql2 sql3; do wait_db_state "$n" "SYNCHRONIZING|SYNCHRONIZED" 120; done
wait_rows sql2 5
wait_rows sql3 5

step "Step 7: AG health (from the primary)"
sql_file sql1 08_ag_health.sql

printf '\n\033[1;32mLab ready.\033[0m Primary: sql1 (localhost,14331). Secondaries: sql2 (14332), sql3 (14333).\n'
