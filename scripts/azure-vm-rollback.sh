#!/usr/bin/env bash
# azure-vm-rollback.sh
# Restore a VM from previously created snapshots: recreate managed disks, swap OS, reattach data disks, restart VM.

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $0 --resource-group RG --vm-name VM_NAME --os-snapshot OS_SNAP_NAME \
     [--data-snapshots snap1,snap2,...] [--new-os-disk-name NEW_OS_DISK] \
     [--new-data-disk-prefix PREFIX] [--subscription SUB_ID]

  --resource-group      : Resource group of VM and snapshots
  --vm-name             : Name of VM to restore
  --os-snapshot         : Snapshot name of OS disk
  --data-snapshots      : (optional) comma-separated snapshot names for data disks
  --new-os-disk-name    : (optional) name for recreated OS disk (default suffix with timestamp)
  --new-data-disk-prefix: (optional) prefix for recreated data disks (default uses VM name + idx + timestamp)
  --subscription        : (optional) subscription ID to set before operations
EOF
  exit 1
}

# parse args
RG="" VM_NAME="" OS_SNAP="" DATA_SNAP_LIST="" NEW_OS_DISK="" DATA_DISK_PREFIX="" SUBSCRIPTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RG="$2"; shift 2;;
    --vm-name) VM_NAME="$2"; shift 2;;
    --os-snapshot) OS_SNAP="$2"; shift 2;;
    --data-snapshots) DATA_SNAP_LIST="$2"; shift 2;;
    --new-os-disk-name) NEW_OS_DISK="$2"; shift 2;;
    --new-data-disk-prefix) DATA_DISK_PREFIX="$2"; shift 2;;
    --subscription) SUBSCRIPTION="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

if [[ -z "$RG" || -z "$VM_NAME" || -z "$OS_SNAP" ]]; then
  echo "ERROR: --resource-group, --vm-name, and --os-snapshot are required"
  usage
fi

if [[ -n "$SUBSCRIPTION" ]]; then
  echo "Setting Azure subscription to $SUBSCRIPTION"
  az account set -s "$SUBSCRIPTION"
fi

TS=$(date +%Y%m%d%H%M%S)
NEW_OS_DISK=${NEW_OS_DISK:-"${VM_NAME}-rollback-os-${TS}"}

echo "Creating OS disk from snapshot '$OS_SNAP' → '$NEW_OS_DISK'"
OSDISK_SOURCE_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG/providers/Microsoft.Compute/snapshots/$OS_SNAP"
az disk create -g "$RG" --name "$NEW_OS_DISK" --source "$OSDISK_SOURCE_ID" --sku Standard_LRS -o json

NEW_DATA_DISKS=()
if [[ -n "$DATA_SNAP_LIST" ]]; then
  IFS=',' read -r -a DATA_ARRAY <<< "$DATA_SNAP_LIST"
  idx=1
  for ds in "${DATA_ARRAY[@]}"; do
    newdd="${DATA_DISK_PREFIX:-${VM_NAME}-rollback-data}${idx}-${TS}"
    echo "Creating data disk from snapshot '$ds' → '$newdd'"
    SNAP_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG/providers/Microsoft.Compute/snapshots/$ds"
    az disk create -g "$RG" --name "$newdd" --source "$SNAP_ID" --sku Standard_LRS -o json
    NEW_DATA_DISKS+=("$newdd")
    idx=$((idx+1))
  done
fi

echo "Deallocating VM '$VM_NAME' in RG '$RG'..."
az vm deallocate -g "$RG" -n "$VM_NAME"

# Wait until deallocated (optional retry logic) ...
# Swap OS disk
NEW_OS_ID=$(az disk show -g "$RG" -n "$NEW_OS_Disk" --query id -o tsv)
echo "Updating VM to use new OS disk ID: $NEW_OS_ID"
az vm update -g "$RG" -n "$VM_NAME" --os-disk "$NEW_OS_ID"

# Detach existing data disks if any
echo "Detaching existing data disks..."
# List data disk names
OLD_DATA_DISKS=$(az vm show -g "$RG" -n "$VM_NAME" --query "storageProfile.dataDisks[].name" -o tsv || echo "")
for dd in $OLD_DATA_DISKS; do
  echo "Detaching disk: $dd"
  az vm disk detach -g "$RG" -n "$VM_NAME" --name "$dd" || echo "Warning: detach may have failed"
done

# Attach restored data disks
if [[ ${#NEW_DATA_DISKS[@]} -gt 0 ]]; then
  echo "Attaching restored data disks..."
  lun=0
  for nd in "${NEW_DATA_DISKS[@]}"; do
    az vm disk attach -g "$RG" -n "$VM_NAME" --name "$nd" --lun "$lun" || { echo "Failed to attach $nd"; exit 1; }
    lun=$((lun+1))
  done
fi

echo "Starting VM '$VM_NAME'..."
az vm start -g "$RG" -n "$VM_NAME"

echo "Rollback complete. VM '$VM_NAME' restored to snapshot state."
