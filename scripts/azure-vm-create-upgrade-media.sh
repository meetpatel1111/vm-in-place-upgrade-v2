#!/usr/bin/env bash
# azure-vm-create-upgrade-media.sh
# Creates a managed disk from Azure Marketplace upgrade image (for Windows Server in-place upgrade).

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --resource-group RG --location LOCATION --disk-name DISK_NAME --sku SERVER_SKU [--subscription SUB_ID] [--zone ZONE] [--disk-sku Standard_LRS|Premium_LRS] [--tags "k=v ..."]
SERVER_SKU must be one of: server2025Upgrade, server2022Upgrade, server2019Upgrade, server2016Upgrade, server2012Upgrade
EOF
  exit 1
}

RG=""
LOCATION=""
DISK_NAME=""
SERVER_SKU=""
SUBSCRIPTION=""
ZONE=""
DISK_SKU="Standard_LRS"
TAGS="upgrade-media=windows-server-upgrade"

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
    *) echo "Unknown arg $1"; usage;;
  esac
done

if [[ -z "$RG" || -z "$LOCATION" || -z "$DISK_NAME" || -z "$SERVER_SKU" ]]; then
  echo "Missing required param"
  usage
fi

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set -s "$SUBSCRIPTION"
fi

PUBLISHER="MicrosoftWindowsServer"
OFFER="WindowsServerUpgrade"
SKU="$SERVER_SKU"

echo "Looking for latest marketplace image for $PUBLISHER / $OFFER / $SKU in $LOCATION..."
VERSION=$(az vm image list --publisher "$PUBLISHER" --offer "$OFFER" --sku "$SKU" --location "$LOCATION" --query "[-1].version" -o tsv)
if [[ -z "$VERSION" ]]; then
  echo "Could not find marketplace image for SKU $SKU in $LOCATION"; exit 2
fi
echo "Found version: $VERSION"

URN="$PUBLISHER:$OFFER:$SKU:$VERSION"
echo "Creating managed disk '$DISK_NAME' from image $URN ..."

if [[ -n "$ZONE" ]]; then
  az disk create -g "$RG" --location "$LOCATION" --name "$DISK_NAME" --image-reference "$URN" --sku "$DISK_SKU" --zone "$ZONE" --tags $TAGS -o json
else
  az disk create -g "$RG" --location "$LOCATION" --name "$DISK_NAME" --image-reference "$URN" --sku "$DISK_SKU" --tags $TAGS -o json
fi

echo "Upgrade-media disk created: $DISK_NAME"
