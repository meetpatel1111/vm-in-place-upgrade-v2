#!/usr/bin/env bash
# post-upgrade-cleanup.sh
# Deletes specified snapshots and/or a managed disk (e.g. upgrade-media disk) after a successful VM upgrade.
# Use with care — deletion is irreversible.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --resource-group RG [--snapshots snap1,snap2,...] [--disk-name DISK_NAME] [--subscription SUB_ID]

  --resource-group  : Azure resource group name (required)
  --snapshots       : Comma-separated names of snapshots to delete (optional)
                     To delete all snapshots with a given name prefix, use pattern (see README)
  --disk-name       : Name of a managed disk to delete (optional)
  --subscription    : Azure subscription ID (optional; overrides default)
EOF
  exit 1
}

RG=""
SUBSCRIPTION=""
SNAPSHOTS=""
DISK_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RG="$2"; shift 2;;
    --snapshots) SNAPSHOTS="$2"; shift 2;;
    --disk-name) DISK_NAME="$2"; shift 2;;
    --subscription) SUBSCRIPTION="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

if [[ -z "$RG" ]]; then
  echo "ERROR: --resource-group is required"
  usage
fi

if [[ -n "${SUBSCRIPTION}" ]]; then
  echo "Setting Azure subscription to ${SUBSCRIPTION}..."
  az account set -s "$SUBSCRIPTION"
fi

# Delete snapshots if provided
if [[ -n "$SNAPSHOTS" ]]; then
  IFS=',' read -r -a SNA_ARRAY <<< "$SNAPSHOTS"
  for snap in "${SNA_ARRAY[@]}"; do
    echo "Deleting snapshot: $snap (resource group: $RG)…"
    az snapshot delete --resource-group "$RG" --name "$snap" --yes \
      && echo " -> Deleted snapshot $snap" \
      || echo " -> Failed to delete snapshot $snap or it may not exist"
  done
else
  echo "No snapshots specified for deletion."
fi

# Delete managed disk if provided
if [[ -n "$DISK_NAME" ]]; then
  echo "Deleting managed disk: $DISK_NAME (resource group: $RG)…"
  az disk delete --resource-group "$RG" --name "$DISK_NAME" --yes \
    && echo " -> Deleted managed disk $DISK_NAME" \
    || echo " -> Failed to delete disk $DISK_NAME or it may not exist / is attached"
else
  echo "No managed disk specified for deletion."
fi

echo "Cleanup script completed."
