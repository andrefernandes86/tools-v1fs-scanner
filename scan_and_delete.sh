#!/bin/sh

export SCAN_PATH=/mnt/scan
export NFS_SERVER=192.168.200.200
export NFS_SHARE=/mnt/nas/malicious-files
export LOG_FILE=/tmp/deletion_log.txt

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Creating mount point..." | tee -a $LOG_FILE
mkdir -p $SCAN_PATH

echo "[$TIMESTAMP] Mounting NFS share $NFS_SERVER:$NFS_SHARE to $SCAN_PATH..." | tee -a $LOG_FILE
mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] Failed to mount NFS share." | tee -a $LOG_FILE
  exit 1
fi

echo "[$TIMESTAMP] Starting scan..." | tee -a $LOG_FILE
tmfs scan -vv dir:$SCAN_PATH \
  --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
  -t "owner=Gandalf" \
  -t "stack=v1fs,schedulescan" 2>&1 | tee /tmp/scan_output.txt

# Extract and delete malicious files
grep -i "malicious" /tmp/scan_output.txt | grep -Eo "$SCAN_PATH[^ ]+" | while read -r file; do
  if [ -f "$file" ]; then
    echo "[$(date)] Deleting malicious file: $file" | tee -a $LOG_FILE
    rm -f "$file" && echo "Deleted: $file" | tee -a $LOG_FILE
  fi
done

echo "[$(date)] Scan complete." | tee -a $LOG_FILE
