#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_NAME="${CONFIG_NAME:-shared}"
TF_ENV_DIR="${TF_ENV_DIR:-shared}"
CONFIG_FILE="${REPO_ROOT}/config/${CONFIG_NAME}.env"
CONFIG_TEMPLATE="${REPO_ROOT}/config/${CONFIG_NAME}.env.example"
DEFAULT_TEMPLATE="${REPO_ROOT}/config/shared.env.example"
TFVARS_FILE="${REPO_ROOT}/infrastructure/envs/${TF_ENV_DIR}/terraform.tfvars"
TFVARS_SNAPSHOT_FILE="${REPO_ROOT}/infrastructure/envs/${TF_ENV_DIR}/terraform.${CONFIG_NAME}.tfvars"
BACKEND_FILE="${REPO_ROOT}/infrastructure/backend/backend-${CONFIG_NAME}.hcl"
CONFIG_WAS_INITIALIZED=false

ensure_config_file() {
  if [[ -f "$CONFIG_FILE" ]]; then
    return
  fi

  if [[ -f "$CONFIG_TEMPLATE" ]]; then
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
    CONFIG_WAS_INITIALIZED=true
    echo "Initialized config from template: $CONFIG_FILE"
    return
  fi

  if [[ -f "$DEFAULT_TEMPLATE" ]]; then
    cp "$DEFAULT_TEMPLATE" "$CONFIG_FILE"
    CONFIG_WAS_INITIALIZED=true
    echo "Initialized config from default template: $CONFIG_FILE"
    return
  fi

  : > "$CONFIG_FILE"
  CONFIG_WAS_INITIALIZED=true
  echo "Initialized empty config file: $CONFIG_FILE"
}

load_config() {
  set -a
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  set +a
}

prompt_value() {
  local var_name="$1"
  local prompt_label="$2"
  local default_value="${3:-}"
  local input=""

  if [[ -n "$default_value" ]]; then
    read -r -p "${prompt_label} [${default_value}]: " input || true
    printf -v "$var_name" '%s' "${input:-$default_value}"
  else
    while [[ -z "${!var_name:-}" ]]; do
      read -r -p "${prompt_label}: " input || true
      printf -v "$var_name" '%s' "$input"
    done
  fi
}

prompt_secret() {
  local var_name="$1"
  local prompt_label="$2"
  local current_value="${!var_name:-}"
  local input=""

  if [[ -n "$current_value" ]]; then
    read -r -s -p "${prompt_label} [preserve current]: " input || true
    echo
    printf -v "$var_name" '%s' "${input:-$current_value}"
  else
    while [[ -z "${!var_name:-}" ]]; do
      read -r -s -p "${prompt_label}: " input || true
      echo
      printf -v "$var_name" '%s' "$input"
    done
  fi
}

prompt_bool() {
  local var_name="$1"
  local prompt_label="$2"
  local default_value="${3:-false}"
  local current_value="${!var_name:-$default_value}"
  local input=""

  while true; do
    read -r -p "${prompt_label} [${current_value}] (true/false): " input || true
    input="${input:-$current_value}"
    if [[ "$input" == "true" || "$input" == "false" ]]; then
      printf -v "$var_name" '%s' "$input"
      return
    fi
    echo "Please answer true or false."
  done
}

effective_current_value() {
  local current_value="$1"
  local derived_default="$2"

  if [[ "$CONFIG_WAS_INITIALIZED" == "true" ]]; then
    printf '%s' "$derived_default"
  else
    printf '%s' "$current_value"
  fi
}

default_location_short() {
  case "${1,,}" in
    westeurope) printf '%s' "weu" ;;
    francecentral) printf '%s' "frc" ;;
    northeurope) printf '%s' "neu" ;;
    swedencentral) printf '%s' "swc" ;;
    germanywestcentral) printf '%s' "gwc" ;;
    *) printf '%s' "${1:0:3}" | tr '[:upper:]' '[:lower:]' ;;
  esac
}

write_config() {
  cat > "$CONFIG_FILE" <<EOT
# Single source of truth for hub-core ${CONFIG_NAME}.

SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
LOCATION=${LOCATION}
LOCATION_SHORT=${LOCATION_SHORT}
ALLOWED_LOCATIONS=${ALLOWED_LOCATIONS}
WORKLOAD=${WORKLOAD}
ENVIRONMENT=${ENVIRONMENT}
ENVIRONMENT_SHORT=${ENVIRONMENT_SHORT}
INSTANCE=${INSTANCE}
HUB_NAME=${HUB_NAME}

# Backend
TFSTATE_RESOURCE_GROUP=${TFSTATE_RESOURCE_GROUP}
TFSTATE_STORAGE_ACCOUNT=${TFSTATE_STORAGE_ACCOUNT}
TFSTATE_CONTAINER=${TFSTATE_CONTAINER}
TFSTATE_KEY=${TFSTATE_KEY}

# Hub resource groups
RG_INFRA_NAME=${RG_INFRA_NAME}

# Hub network
HUB_VNET_CIDR=${HUB_VNET_CIDR}
HUB_NVA_UNTRUST_SUBNET_CIDR=${HUB_NVA_UNTRUST_SUBNET_CIDR}
HUB_NVA_TRUST_SUBNET_CIDR=${HUB_NVA_TRUST_SUBNET_CIDR}
HUB_NVA_TRUST_PRIVATE_IP=${HUB_NVA_TRUST_PRIVATE_IP}

# OPNsense
OPNSENSE_VM_SIZE=${OPNSENSE_VM_SIZE}
OPNSENSE_ADMIN_USERNAME=${OPNSENSE_ADMIN_USERNAME}
OPNSENSE_ADMIN_PASSWORD=${OPNSENSE_ADMIN_PASSWORD}

# Governance
TAG_OWNER=${TAG_OWNER}
TAG_COST_CENTER=${TAG_COST_CENTER}
EOT
}

ensure_config_file
load_config

prompt_value "SUBSCRIPTION_ID" "Azure subscription ID" "${SUBSCRIPTION_ID:-}"
prompt_value "LOCATION" "Azure location" "${LOCATION:-francecentral}"
prompt_value "LOCATION_SHORT" "Azure location short code" "${LOCATION_SHORT:-$(default_location_short "${LOCATION:-francecentral}")}"

# The hub package now represents shared connectivity only.
# Keep these values opinionated and stable to avoid noisy prompts.
ALLOWED_LOCATIONS="${ALLOWED_LOCATIONS:-westeurope,francecentral}"
WORKLOAD="${WORKLOAD:-mlops}"
ENVIRONMENT="${ENVIRONMENT:-staging}"
ENVIRONMENT_SHORT="${ENVIRONMENT_SHORT:-stg}"

prompt_value "INSTANCE" "Instance" "${INSTANCE:-01}"
prompt_value "HUB_NAME" "Hub base name" "${HUB_NAME:-hub}"

derived_tfstate_resource_group="rg-tfstate-platform-${ENVIRONMENT_SHORT:-stg}-${LOCATION_SHORT:-frc}-${INSTANCE:-01}"
derived_tfstate_storage_account="sttfplatform${ENVIRONMENT_SHORT:-stg}${LOCATION_SHORT:-frc}${INSTANCE:-01}"
derived_tfstate_key="hub-core-${CONFIG_NAME}.tfstate"
prompt_value "TFSTATE_RESOURCE_GROUP" "Terraform state resource group" "$derived_tfstate_resource_group"
prompt_value "TFSTATE_STORAGE_ACCOUNT" "Terraform state storage account" "$derived_tfstate_storage_account"
prompt_value "TFSTATE_CONTAINER" "Terraform state container" "${TFSTATE_CONTAINER:-tfstate}"
prompt_value "TFSTATE_KEY" "Terraform state key" "$derived_tfstate_key"

prompt_value "RG_INFRA_NAME" "Hub infra resource group" "${RG_INFRA_NAME:-rg-${HUB_NAME:-hub}}"

prompt_value "HUB_VNET_CIDR" "Hub VNet CIDR" "${HUB_VNET_CIDR:-10.0.0.0/22}"
prompt_value "HUB_NVA_UNTRUST_SUBNET_CIDR" "NVA untrust subnet CIDR" "${HUB_NVA_UNTRUST_SUBNET_CIDR:-10.0.0.64/26}"
prompt_value "HUB_NVA_TRUST_SUBNET_CIDR" "NVA trust subnet CIDR" "${HUB_NVA_TRUST_SUBNET_CIDR:-10.0.0.128/26}"
prompt_value "HUB_NVA_TRUST_PRIVATE_IP" "NVA trust private IP" "${HUB_NVA_TRUST_PRIVATE_IP:-10.0.0.132}"

prompt_value "OPNSENSE_VM_SIZE" "OPNsense VM size" "${OPNSENSE_VM_SIZE:-Standard_D2s_v3}"
prompt_value "OPNSENSE_ADMIN_USERNAME" "OPNsense admin username" "${OPNSENSE_ADMIN_USERNAME:-azureuser}"
prompt_secret "OPNSENSE_ADMIN_PASSWORD" "OPNsense admin password"

prompt_value "TAG_OWNER" "Owner tag" "${TAG_OWNER:-tfm}"
prompt_value "TAG_COST_CENTER" "Cost center tag" "${TAG_COST_CENTER:-master}"

write_config

load_config

cat > "$TFVARS_FILE" <<EOT
subscription_id             = "${SUBSCRIPTION_ID}"
location                    = "${LOCATION}"
location_short              = "${LOCATION_SHORT}"
allowed_locations           = [$(printf '"%s"' "${ALLOWED_LOCATIONS//,/\",\"}")]
workload                    = "${WORKLOAD}"
environment                 = "${ENVIRONMENT}"
environment_short           = "${ENVIRONMENT_SHORT}"
instance                    = "${INSTANCE}"
hub_name                    = "${HUB_NAME}"
rg_infra_name               = "${RG_INFRA_NAME}"
hub_vnet_cidr               = "${HUB_VNET_CIDR}"
hub_nva_untrust_subnet_cidr = "${HUB_NVA_UNTRUST_SUBNET_CIDR}"
hub_nva_trust_subnet_cidr   = "${HUB_NVA_TRUST_SUBNET_CIDR}"
hub_nva_trust_private_ip    = "${HUB_NVA_TRUST_PRIVATE_IP}"
opnsense_vm_size            = "${OPNSENSE_VM_SIZE}"
opnsense_admin_username     = "${OPNSENSE_ADMIN_USERNAME}"
opnsense_admin_password     = "${OPNSENSE_ADMIN_PASSWORD}"
tag_owner                   = "${TAG_OWNER}"
tag_cost_center             = "${TAG_COST_CENTER}"
EOT

cp "$TFVARS_FILE" "$TFVARS_SNAPSHOT_FILE"

cat > "$BACKEND_FILE" <<EOT
resource_group_name  = "${TFSTATE_RESOURCE_GROUP}"
storage_account_name = "${TFSTATE_STORAGE_ACCOUNT}"
container_name       = "${TFSTATE_CONTAINER}"
key                  = "${TFSTATE_KEY}"
EOT

echo "Generated: $TFVARS_FILE"
echo "Generated: $TFVARS_SNAPSHOT_FILE"
echo "Generated: $BACKEND_FILE"
echo "Saved config: $CONFIG_FILE"
