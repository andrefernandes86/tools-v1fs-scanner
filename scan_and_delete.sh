#!/bin/sh
# With Recursive Scan and Quarantine Function

export SCAN_PATH=/mnt/scan
export NFS_SERVER=192.168.200.10
export NFS_SHARE=/mnt/nfs_share
export LOG_FILE=/tmp/deletion_log.txt
export SCAN_JSON=/tmp/scan_result.json
export QUARANTINE_DIR="$SCAN_PATH/quarantine"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Creating mount point..."
mkdir -p $SCAN_PATH

echo "[$TIMESTAMP] Mounting NFS share $NFS_SERVER:$NFS_SHARE to $SCAN_PATH..."
mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] ❌ Failed to mount NFS share." | tee -a $LOG_FILE
  exit 1
fi

# Create quarantine directory
echo "[$TIMESTAMP] Creating quarantine directory..."
mkdir -p "$QUARANTINE_DIR"
chmod 755 "$QUARANTINE_DIR"

echo "[$TIMESTAMP] 🔍 Starting recursive directory scan..." | tee -a $LOG_FILE

# Function to quarantine a file
quarantine_file() {
  local file="$1"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local filename=$(basename "$file")
  local dirname=$(dirname "$file")
  local name_without_ext="${filename%.*}"
  local extension="${filename##*.}"
  
  # Create quarantine filename with timestamp and .quarantine extension
  local quarantine_name="${name_without_ext}_${timestamp}.quarantine"
  local quarantine_path="$QUARANTINE_DIR/$quarantine_name"
  
  # Move file to quarantine
  if mv "$file" "$quarantine_path" 2>/dev/null; then
    # Change permissions to prevent execution (read-only for owner, no access for others)
    chmod 400 "$quarantine_path"
    echo "✅ Quarantined: $file -> $quarantine_path" | tee -a $LOG_FILE
    echo "   Original location: $dirname" | tee -a $LOG_FILE
    echo "   Original extension: $extension" | tee -a $LOG_FILE
    echo "   New permissions: $(ls -la "$quarantine_path" | awk '{print $1}')" | tee -a $LOG_FILE
  else
    echo "❌ Failed to quarantine: $file (Permission denied or file busy)" | tee -a $LOG_FILE
    # If move fails, try to copy and then delete
    if cp "$file" "$quarantine_path" 2>/dev/null; then
      chmod 400 "$quarantine_path"
      rm -f "$file" 2>/dev/null
      echo "✅ Copied and quarantined: $file -> $quarantine_path" | tee -a $LOG_FILE
    else
      echo "❌ Failed to copy/quarantine: $file" | tee -a $LOG_FILE
    fi
  fi
}

# Loop through all subdirectories and the base path itself
find "$SCAN_PATH" -type d | while IFS= read -r dir; do
  # Skip the quarantine directory itself
  if [ "$dir" = "$QUARANTINE_DIR" ]; then
    continue
  fi
  
  echo "[+] Scanning directory: $dir" | tee -a $LOG_FILE
  tmfs scan -vv dir:"$dir" \
    --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
    -t "owner=Gandalf" \
    -t "stack=v1fs,schedulescan" > "$SCAN_JSON"

  echo "[*] Parsing results from: $dir" | tee -a $LOG_FILE
  jq -r '.scanResults[] | select(.scanResult==1) | .fileName' "$SCAN_JSON" | while read -r file; do
    if [ -f "$file" ]; then
      echo "🚨 Malicious file detected: $file" | tee -a $LOG_FILE
      quarantine_file "$file"
    else
      echo "⚠️ Not found: $file" | tee -a $LOG_FILE
    fi
  done
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Full recursive scan and quarantine complete." | tee -a $LOG_FILE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📁 Quarantined files are stored in: $QUARANTINE_DIR" | tee -a $LOG_FILE
