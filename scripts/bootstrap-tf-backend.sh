#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_NAME="${CONFIG_NAME:-shared}"
CONFIG_FILE="${REPO_ROOT}/config/${CONFIG_NAME}.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi

set -a
source "$CONFIG_FILE"
set +a

az account set --subscription "$SUBSCRIPTION_ID" >/dev/null

TAGS="project=${WORKLOAD} environment=shared owner=${TAG_OWNER}"

az group create --name "$TFSTATE_RESOURCE_GROUP" --location "$LOCATION" --tags $TAGS
az storage account create \
  --name "$TFSTATE_STORAGE_ACCOUNT" \
  --resource-group "$TFSTATE_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --public-network-access Enabled \
  --allow-blob-public-access false \
  --tags $TAGS

ACCOUNT_KEY=$(az storage account keys list --resource-group "$TFSTATE_RESOURCE_GROUP" --account-name "$TFSTATE_STORAGE_ACCOUNT" --query '[0].value' -o tsv)

az storage container create \
  --name "$TFSTATE_CONTAINER" \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" \
  --account-key "$ACCOUNT_KEY"

# Soft delete para blobs y contenedores
az storage account blob-service-properties update \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" \
  --resource-group "$TFSTATE_RESOURCE_GROUP" \
  --enable-delete-retention true \
  --delete-retention-days 7 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 7
