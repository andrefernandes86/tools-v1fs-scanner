#!/bin/sh

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Mounting NFS share..."
mkdir /mnt/scan

mkdir -p $SCAN_PATH
mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] Failed to mount NFS share."
  exit 1
fi

echo "[$TIMESTAMP] Running TMFS scan..."
SCAN_OUTPUT=$(tmfs scan -v dir:$SCAN_PATH \
  --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
  -t "owner=Gandalf" \
  -t "stack=v1fs,schedulescan" 2>&1)

echo "$SCAN_OUTPUT" > $SCAN_LOG
echo "$TIMESTAMP - Scan completed." >> $LOG_FILE

# Detect and delete malicious files based on scan output
echo "$SCAN_OUTPUT" | grep -i "malicious" | grep -Eo "$SCAN_PATH[^ ]*" | while read -r file; do
  if [ -f "$file" ]; then
    rm -f "$file" && echo "Deleted: $file" >> $LOG_FILE
  fi
done

echo "[$(date "+%Y-%m-%d %H:%M:%S")] Cleanup complete." >> $LOG_FILE
