#!/bin/sh
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Mounting NFS share..." >> $LOG_FILE

mkdir -p $SCAN_PATH
mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] Failed to mount NFS share." >> $LOG_FILE
  exit 1
fi

echo "[$TIMESTAMP] Starting TMFS scan..." >> $LOG_FILE
tmfs scan \
  --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
  dir:$SCAN_PATH \
  --tag "owner=Gandalf" \
  --tag "stack=v1fs, schedulescan" \
  --output $SCAN_LOG \
  --output-format json

if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] TMFS scan failed." >> $LOG_FILE
  exit 1
fi

if ! jq empty $SCAN_LOG 2>/dev/null; then
  echo "[$TIMESTAMP] Invalid JSON from TMFS." >> $LOG_FILE
  exit 1
fi

jq -r '.scanResults[] | select(.scanResult==1) | .fileName' $SCAN_LOG | while read -r filepath; do
  if [ -n "$filepath" ] && [ -f "$filepath" ]; then
    rm -f "$filepath"
    if [ $? -eq 0 ]; then
      echo "[$TIMESTAMP] Deleted: $filepath" >> $LOG_FILE
    else
      echo "[$TIMESTAMP] Failed to delete: $filepath" >> $LOG_FILE
    fi
  else
    echo "[$TIMESTAMP] File not found or empty path: $filepath" >> $LOG_FILE
  fi
done

echo "[$TIMESTAMP] Scan-and-delete cycle complete." >> $LOG_FILE
