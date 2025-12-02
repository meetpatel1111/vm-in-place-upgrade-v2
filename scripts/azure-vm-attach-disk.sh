#!/usr/bin/env bash
# azure-vm-attach-disk.sh
# Attach an existing managed disk (e.g. upgrade media) to a VM.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --vm-name VM_NAME --resource-group RG --disk-name DISK_NAME [--subscription SUB_ID] [--lun LUN] [--caching ReadOnly|ReadWrite|None]
  --vm-name        Name of the VM
  --resource-group Resource group of the VM and disk
  --disk-name      Managed disk name to attach
Optional:
  --subscription   If provided, set this subscription before attach
  --lun            LUN (logical unit number) for data disk. Default: let Azure decide.
  --caching        Disk caching setting (None, ReadOnly, ReadWrite). Default: None.
EOF
  exit 1
}

VM_NAME=""
RG=""
DISK_NAME=""
SUBSCRIPTION=""
LUN=""
CACHING="None"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; shift 2;;
    --resource-group) RG="$2"; shift 2;;
    --disk-name) DISK_NAME="$2"; shift 2;;
    --subscription) SUBSCRIPTION="$2"; shift 2;;
    --lun) LUN="$2"; shift 2;;
    --caching) CACHING="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown argument: $1"; usage;;
  esac
done

if [[ -z "$VM_NAME" || -z "$RG" || -z "$DISK_NAME" ]]; then
  echo "Missing required arguments."
  usage
fi

if [[ -n "${SUBSCRIPTION}" ]]; then
  echo "Setting Azure subscription to $SUBSCRIPTION ..."
  az account set -s "$SUBSCRIPTION"
fi

echo "Attaching disk '$DISK_NAME' to VM '$VM_NAME' in RG '$RG'..."

# Attach the disk
CMD=( az vm disk attach --vm-name "$VM_NAME" --resource-group "$RG" --name "$DISK_NAME" --caching "$CACHING" )
if [[ -n "$LUN" ]]; then
  CMD+=( --lun "$LUN" )
fi

"${CMD[@]}" -o json

echo "Disk attached successfully."
