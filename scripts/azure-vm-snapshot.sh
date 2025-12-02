#!/usr/bin/env bash
# azure-vm-snapshot.sh
# Creates snapshots of an Azure VM's managed OS disk + optionally data disks.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --vm-name VM_NAME --resource-group RG [--subscription SUB_ID] [--snapshot-prefix PREFIX] [--include-data-disks true|false] [--snapshot-sku Standard_LRS|Premium_LRS] [--tags "k=v ..."]
EOF
  exit 1
}

VM_NAME=""
RG=""
SUBSCRIPTION=""
SNAP_PREFIX=""
INCLUDE_DATA="true"
SNAP_SKU="Standard_LRS"
TAGS="createdBy=github-actions"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; shift 2;;
    --resource-group) RG="$2"; shift 2;;
    --subscription) SUBSCRIPTION="$2"; shift 2;;
    --snapshot-prefix) SNAP_PREFIX="$2"; shift 2;;
    --include-data-disks) INCLUDE_DATA="$2"; shift 2;;
    --snapshot-sku) SNAP_SKU="$2"; shift 2;;
    --tags) TAGS="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown argument: $1"; usage;;
  esac
done

if [[ -z "$VM_NAME" || -z "$RG" ]]; then
  echo "Error: --vm-name and --resource-group are required"
  usage
fi

if [[ -n "$SUBSCRIPTION" ]]; then
  az account set -s "$SUBSCRIPTION"
fi

# Get OS disk ID
OS_ID=$(az vm show -g "$RG" -n "$VM_NAME" --query "storageProfile.osDisk.managedDisk.id" -o tsv)
if [[ -z "$OS_ID" ]]; then
  echo "Failed to get OS disk ID"; exit 2
fi

# Get data disks IDs
mapfile -t DATA_IDS < <(az vm show -g "$RG" -n "$VM_NAME" --query "storageProfile.dataDisks[].managedDisk.id" -o tsv || true)

TS=$(date +%Y%m%d%H%M%S)
PREFIX=${SNAP_PREFIX:-"${VM_NAME}-snapshot"}

# Snapshot OS disk
SNAP_OS="${PREFIX}-os-${TS}"
echo "Creating snapshot $SNAP_OS from OS disk..."
az snapshot create -g "$RG" --name "$SNAP_OS" --source "$OS_ID" --sku "$SNAP_SKU" --tags $TAGS -o json

# Snapshot data disks if requested
if [[ "${INCLUDE_DATA,,}" == "true" ]]; then
  idx=1
  for did in "${DATA_IDS[@]}"; do
    SNAP_D="${PREFIX}-data${idx}-${TS}"
    echo "Creating snapshot $SNAP_D from data disk (id: $did)..."
    az snapshot create -g "$RG" --name "$SNAP_D" --source "$did" --sku "$SNAP_SKU" --tags $TAGS -o json
    idx=$((idx+1))
  done
else
  echo "Skipping data disk snapshots."
fi

echo "Snapshot(s) created."
