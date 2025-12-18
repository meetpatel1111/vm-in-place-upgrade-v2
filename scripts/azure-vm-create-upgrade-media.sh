#!/usr/bin/env bash
# azure-vm-create-upgrade-media.sh
# Creates a managed disk from the hidden WindowsServerUpgrade marketplace image
# (Functional equivalent of the provided PowerShell Az script)

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --resource-group RG --location LOCATION --disk-name DISK_NAME --sku SERVER_SKU
          [--subscription SUB_ID] [--zone ZONE] [--disk-sku Standard_LRS|Premium_LRS]
          [--tags "k=v ..."]

SERVER_SKU must be one of:
  server2025Upgrade | server2022Upgrade | server2019Upgrade | server2016Upgrade | server2012Upgrade
EOF
  exit 1
}

# -------------------------
# Inputs (from workflow)
# -------------------------
RG=""
LOCATION=""
DISK_NAME=""
SERVER_SKU=""
SUBSCRIPTION=""
ZONE=""
DISK_SKU="Standard_LRS"
TAGS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RG="$2"; shift 2;;
    --location) LOCATION="$2"; shift 2;;
    --disk-name) DISK_NAME="$2"; shift 2;;
    --sku) SERVER_SKU="$2"; shift 2;;
    --subscription) SUBSCRIPTION="$2"; shift 2;;
    --zone) ZONE="$2"; shift 2;;
    --disk-sku) DISK_SKU="$2"; shift 2;;
    --tags) TAGS="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown argument: $1"; usage;;
  esac
done

if [[ -z "$RG" || -z "$LOCATION" || -z "$DISK_NAME" || -z "$SERVER_SKU" ]]; then
  echo "ERROR: Missing required parameters"
  usage
fi

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set --subscription "$SUBSCRIPTION"
fi

# -------------------------
# Marketplace constants
# -------------------------
PUBLISHER="MicrosoftWindowsServer"
OFFER="WindowsServerUpgrade"
SKU="$SERVER_SKU"

echo "Resolving latest hidden upgrade image..."
echo "Publisher : $PUBLISHER"
echo "Offer     : $OFFER"
echo "SKU       : $SKU"
echo "Location  : $LOCATION"

# -------------------------
# Get latest image version (hidden image)
# -------------------------
LATEST_VERSION=$(az vm image list \
  --publisher "$PUBLISHER" \
  --offer "$OFFER" \
  --sku "$SKU" \
  --location "$LOCATION" \
  --all \
  --query "sort_by([].version, &to_string(@))[-1]" \
  -o tsv)

if [[ -z "$LATEST_VERSION" ]]; then
  echo "ERROR: No upgrade image found for SKU '$SKU' in $LOCATION"
  exit 2
fi

echo "Latest version: $LATEST_VERSION"

IMAGE_ID=$(az vm image show \
  --publisher "$PUBLISHER" \
  --offer "$OFFER" \
  --sku "$SKU" \
  --version "$LATEST_VERSION" \
  --location "$LOCATION" \
  --query "id" \
  -o tsv)

if [[ -z "$IMAGE_ID" ]]; then
  echo "ERROR: Failed to resolve image ID"
  exit 3
fi

echo "Image ID:"
echo "$IMAGE_ID"

# -------------------------
# Ensure resource group exists
# -------------------------
az group create \
  --name "$RG" \
  --location "$LOCATION" \
  --output none

# -------------------------
# Create managed disk from image (LUN 0)
# -------------------------
DISK_ARGS=(
  --resource-group "$RG"
  --name "$DISK_NAME"
  --location "$LOCATION"
  --sku "$DISK_SKU"
  --source "$IMAGE_ID"
)

if [[ -n "$ZONE" ]]; then
  DISK_ARGS+=(--zone "$ZONE")
fi

if [[ -n "$TAGS" ]]; then
  DISK_ARGS+=(--tags $TAGS)
fi

echo "Creating upgrade media managed disk..."
az disk create "${DISK_ARGS[@]}"

echo "SUCCESS: Upgrade media disk created"
echo "Disk Name       : $DISK_NAME"
echo "Resource Group  : $RG"
echo "Upgrade SKU     : $SKU"
