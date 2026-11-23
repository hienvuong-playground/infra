#!/usr/bin/env bash
# Starts or stops AKS and Postgres together. The nightly runbooks (cloud/runbook.tf) only stop.
set -euo pipefail

verb=${1:-}
case $verb in
  start) aks_target=Running pg_target=Ready ;;
  stop) aks_target=Stopped pg_target=Stopped ;;
  *) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac

# Pinned, so it never acts on whatever subscription az currently defaults to
SUB=Playground
RG=rg-playground
AKS=aks-playground
# Server name has a random suffix
PG=$(az postgres flexible-server list --subscription "$SUB" -g "$RG" --query "[0].name" -o tsv)

aks() { az aks "$1" --subscription "$SUB" -g "$RG" -n "$AKS" "${@:2}"; }
pg() { az postgres flexible-server "$1" --subscription "$SUB" -g "$RG" -n "$PG" "${@:2}"; }

# $1 label, $2 wrapper, $3 state query, $4 target state
toggle() {
  local label=$1 cmd=$2 query=$3 target=$4 state
  state=$("$cmd" show --query "$query" -o tsv)
  if [[ $state == "$target" ]]; then
    echo "$label already $target"
    return
  fi
  echo "$label: $verb ($state -> $target)..."
  "$cmd" "$verb"
  echo "$label: $target"
}

toggle "AKS $AKS" aks powerState.code "$aks_target" & aks_pid=$!
toggle "Postgres $PG" pg state "$pg_target" & pg_pid=$!

status=0
wait "$aks_pid" || { echo "AKS $verb failed" >&2; status=1; }
wait "$pg_pid" || { echo "Postgres $verb failed" >&2; status=1; }
exit "$status"
