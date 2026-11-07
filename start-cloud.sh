#!/usr/bin/env bash
# Starts what the nightly runbooks stop (cloud/runbook.tf).
set -euo pipefail

RG=rg-playground
AKS=aks-playground
# Server name has a random suffix
PSQL=$(az postgres flexible-server list -g "$RG" --query "[0].name" -o tsv)

start_aks() {
  if [[ $(az aks show -g "$RG" -n "$AKS" --query powerState.code -o tsv) == Running ]]; then
    echo "AKS $AKS already running"
  else
    echo "Starting AKS $AKS..."
    az aks start -g "$RG" -n "$AKS"
    echo "AKS $AKS started"
  fi
}

start_psql() {
  if [[ $(az postgres flexible-server show -g "$RG" -n "$PSQL" --query state -o tsv) == Ready ]]; then
    echo "Postgres $PSQL already running"
  else
    echo "Starting Postgres $PSQL..."
    az postgres flexible-server start -g "$RG" -n "$PSQL"
    echo "Postgres $PSQL started"
  fi
}

start_aks & aks_pid=$!
start_psql & psql_pid=$!

status=0
wait "$aks_pid" || { echo "AKS start failed" >&2; status=1; }
wait "$psql_pid" || { echo "Postgres start failed" >&2; status=1; }
exit "$status"
