#!/usr/bin/env bash
# Checks the runner has every right init needs, then creates what init itself needs
# before it can run: registered resource providers and the storage account holding
# init's own state. Idempotent. See ADR 0016.
set -euo pipefail
cd "$(dirname "$0")"

BACKEND_FILE=../terraform-backend/init.tfbackend
TFVARS=secrets.auto.tfvars
read_backend() { sed -n "s/^$1 *= *\"\(.*\)\"/\1/p" "$BACKEND_FILE"; }
STORAGE_ACCOUNT=$(read_backend storage_account_name)
CONTAINER=$(read_backend container_name)
GITHUB_ORG=$(sed -n 's/^ *name *= *"\(.*\)"/\1/p' locals.tf)
RESOURCE_GROUP=rg-playground-init-state
LOCATION=westeurope
GLOBAL_ADMIN_TEMPLATE_ID=62e90394-69f5-4237-9190-012177145e10

# --- Preflight: report every missing right at once, before anything is created ---
errors=()
fail() { errors+=("$1"); }

for cmd in az curl jq; do
  command -v "$cmd" >/dev/null || fail "missing command: $cmd"
done

SUBSCRIPTION=$(az account show --query id -o tsv)
echo "Subscription: $(az account show --query name -o tsv) ($SUBSCRIPTION)"
ME=$(az ad signed-in-user show --query id -o tsv)

owner=$(az role assignment list --assignee "$ME" --role Owner --scope "/subscriptions/$SUBSCRIPTION" \
  --include-inherited --include-groups --query 'length(@)')
[[ $owner -gt 0 ]] || fail "Azure: not Owner on subscription $SUBSCRIPTION"

# transitiveMemberOf also covers roles assigned through a group. A PIM-eligible role
# only shows up once activated.
global_admin=$(az rest --method get \
  --url "https://graph.microsoft.com/v1.0/me/transitiveMemberOf/microsoft.graph.directoryRole?\$select=roleTemplateId" \
  --query "length(value[?roleTemplateId=='$GLOBAL_ADMIN_TEMPLATE_ID'])")
[[ $global_admin -gt 0 ]] || fail "Entra: not Global Administrator (activate it first if it is PIM-eligible)"

if [[ ! -f $TFVARS ]]; then
  fail "missing init/$TFVARS"
else
  grep -q '^github_app_pem' "$TFVARS" || fail "$TFVARS: github_app_pem not set"
  GITHUB_TOKEN=$(sed -n 's/^github_token *= *"\(.*\)"/\1/p' "$TFVARS")
  if [[ -z $GITHUB_TOKEN ]]; then
    fail "$TFVARS: github_token not set"
  else
    scopes=$(curl -sSI -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user |
      tr -d '\r' | sed -n 's/^x-oauth-scopes: *//Ip' | tr ',' '\n' | tr -d ' ')
    for scope in admin:org repo; do
      grep -qx "$scope" <<<"$scopes" || fail "GitHub PAT: missing scope $scope"
    done
    role=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" \
      "https://api.github.com/user/memberships/orgs/$GITHUB_ORG" | jq -r '.role // empty')
    [[ $role == admin ]] || fail "GitHub: PAT owner is not admin of org $GITHUB_ORG"
  fi
fi

if ((${#errors[@]})); then
  printf 'Preflight failed:\n' >&2
  printf '  - %s\n' "${errors[@]}" >&2
  exit 1
fi
echo "Preflight OK"

# azurerm 5.x registers no providers by default. Derived from the resource types in
# init, cloud and k8s/terraform; Flux on AKS needs Kubernetes + KubernetesConfiguration.
PROVIDERS=(
  Microsoft.Storage Microsoft.ManagedIdentity Microsoft.ContainerService Microsoft.Compute
  Microsoft.Network Microsoft.ContainerRegistry Microsoft.KeyVault Microsoft.DBforPostgreSQL
  Microsoft.ServiceBus Microsoft.OperationalInsights Microsoft.Insights Microsoft.Monitor
  Microsoft.Automation Microsoft.Kubernetes Microsoft.KubernetesConfiguration
)

az provider register --namespace Microsoft.Storage --wait
for ns in "${PROVIDERS[@]}"; do
  az provider register --namespace "$ns"
done

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-shared-key-access false \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --output none

az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --output none

# Owner has no blob data-plane rights, and the backend uses Entra auth.
SCOPE=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
if [[ $(az role assignment list --assignee "$ME" --role "Storage Blob Data Contributor" --scope "$SCOPE" --query 'length(@)') == 0 ]]; then
  az role assignment create \
    --assignee-object-id "$ME" \
    --assignee-principal-type User \
    --role "Storage Blob Data Contributor" \
    --scope "$SCOPE" \
    --output none
fi

# New role assignments take a few minutes to propagate.
for attempt in $(seq 1 20); do
  if az storage container create --name "$CONTAINER" --account-name "$STORAGE_ACCOUNT" --auth-mode login --output none 2>/dev/null; then
    echo "Ready: $STORAGE_ACCOUNT/$CONTAINER"
    exit 0
  fi
  echo "Waiting for role propagation ($attempt/20)..."
  sleep 30
done
echo "Container creation still failing after 10 minutes" >&2
exit 1
