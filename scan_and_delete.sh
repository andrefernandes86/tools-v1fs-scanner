#!/bin/sh
# With Recursive Scan

# Source config.env if present
if [ -f /config.env ]; then
  . /config.env
elif [ -f ./config.env ]; then
  . ./config.env
fi

# Use environment variables or safe defaults
export SCAN_PATH="${SCAN_PATH:-/mnt/scan}"
export NFS_SERVER="${NFS_SERVER:-192.168.200.200}"
export NFS_SHARE="${NFS_SHARE:-/mnt/nas/malicious-files}"
export LOG_FILE="${LOG_FILE:-/tmp/deletion_log.txt}"
export SCAN_JSON="${SCAN_JSON:-/tmp/scan_result.json}"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Creating mount point..."
mkdir -p $SCAN_PATH

echo "[$TIMESTAMP] Mounting NFS share $NFS_SERVER:$NFS_SHARE to $SCAN_PATH..."
mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] ❌ Failed to mount NFS share." | tee -a $LOG_FILE
  exit 1
fi

echo "[$TIMESTAMP] 🔍 Starting recursive directory scan..." | tee -a $LOG_FILE

# Loop through all subdirectories and the base path itself
find "$SCAN_PATH" -type d | while IFS= read -r dir; do
  echo "[+] Scanning directory: $dir" | tee -a $LOG_FILE
  tmfs scan -vv dir:"$dir" \
    --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
    -t "owner=Gandalf" \
    -t "stack=v1fs,schedulescan" > "$SCAN_JSON"

  echo "[*] Parsing results from: $dir" | tee -a $LOG_FILE
  jq -r '.scanResults[] | select(.scanResult==1) | .fileName' "$SCAN_JSON" | while read -r file; do
    if [ -f "$file" ]; then
      echo "Deleting: $file" | tee -a $LOG_FILE
      rm -f "$file" && echo "✅ Deleted: $file" | tee -a $LOG_FILE
    else
      echo "⚠️ Not found: $file" | tee -a $LOG_FILE
    fi
  done
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Full recursive scan and cleanup complete." | tee -a $LOG_FILE
