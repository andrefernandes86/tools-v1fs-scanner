#!/bin/sh

export SCAN_PATH=/mnt/scan
export NFS_SERVER=192.168.200.200
export NFS_SHARE=/mnt/nas/malicious-files
export LOG_FILE=/tmp/deletion_log.txt
export SCAN_JSON=/tmp/scan_result.json

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Creating mount point..."
mkdir -p $SCAN_PATH

echo "[$TIMESTAMP] Mounting NFS share $NFS_SERVER:$NFS_SHARE to $SCAN_PATH..."
mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] ❌ Failed to mount NFS share." | tee -a $LOG_FILE
  exit 1
fi

echo "[$TIMESTAMP] 🔍 Running TMFS scan on $SCAN_PATH..." | tee -a $LOG_FILE
tmfs scan -vv dir:$SCAN_PATH \
  --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
  -t "owner=Gandalf" \
  -t "stack=v1fs,schedulescan" > $SCAN_JSON

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🧹 Parsing and deleting malicious files..." | tee -a $LOG_FILE
jq -r '.scanResults[] | select(.scanResult==1) | .fileName' "$SCAN_JSON" | while read -r file; do
  if [ -f "$file" ]; then
    echo "Deleting: $file" | tee -a $LOG_FILE
    rm -f "$file" && echo "✅ Deleted: $file" | tee -a $LOG_FILE
  else
    echo "⚠️ Not found: $file" | tee -a $LOG_FILE
  fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Scan and cleanup complete." | tee -a $LOG_FILE
