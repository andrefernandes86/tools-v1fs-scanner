#!/bin/sh
# Continuous Recursive Scan and Quarantine Function with Real-time Monitoring and Parallel Processing

export SCAN_PATH=/mnt/scan
export NFS_SERVER=192.168.200.10
export NFS_SHARE=/mnt/nfs_share
export LOG_FILE=/tmp/deletion_log.txt
export SCAN_JSON=/tmp/scan_result.json
export QUARANTINE_DIR="$SCAN_PATH/quarantine"
export SCAN_INTERVAL=30  # Scan interval in seconds

# Parallel scanning configuration
export MAX_PARALLEL_SCANS=3  # Maximum number of parallel directory scans
export PARALLEL_DELAY=1      # Delay between parallel requests (seconds)
export ENABLE_PARALLEL=true  # Enable/disable parallel scanning

# Function to initialize the scanning environment
initialize_scan() {
  local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$TIMESTAMP] 🚀 Initializing continuous recursive scan system..." | tee -a $LOG_FILE
  
  echo "[$TIMESTAMP] Creating mount point..."
  mkdir -p $SCAN_PATH

  echo "[$TIMESTAMP] Mounting NFS share $NFS_SERVER:$NFS_SHARE to $SCAN_PATH..."
  mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
  if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] ❌ Failed to mount NFS share." | tee -a $LOG_FILE
    return 1
  fi

  # Create quarantine directory
  echo "[$TIMESTAMP] Creating quarantine directory..."
  mkdir -p "$QUARANTINE_DIR"
  chmod 755 "$QUARANTINE_DIR"
  
  # Display parallel scanning configuration
  if [ "$ENABLE_PARALLEL" = "true" ]; then
    echo "[$TIMESTAMP] ⚡ Parallel scanning enabled: Max $MAX_PARALLEL_SCANS concurrent scans" | tee -a $LOG_FILE
    echo "[$TIMESTAMP] ⏱️  Rate limiting: $PARALLEL_DELAY second delay between parallel requests" | tee -a $LOG_FILE
  else
    echo "[$TIMESTAMP] 🐌 Sequential scanning enabled" | tee -a $LOG_FILE
  fi
  
  echo "[$TIMESTAMP] ✅ Initialization complete. Starting continuous monitoring..." | tee -a $LOG_FILE
  return 0
}

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

# Function to perform recursive scan of a single directory
scan_directory() {
  local dir="$1"
  local scan_count="$2"
  local process_id="$3"
  
  # Skip the quarantine directory itself - CRITICAL EXCLUSION
  if [ "$dir" = "$QUARANTINE_DIR" ] || echo "$dir" | grep -q "^$QUARANTINE_DIR/"; then
    echo "[Scan #$scan_count][PID:$process_id] 🚫 Skipping quarantine directory: $dir" | tee -a $LOG_FILE
    return 0
  fi
  
  echo "[Scan #$scan_count][PID:$process_id] [+] Scanning directory: $dir" | tee -a $LOG_FILE
  
  # Create unique scan result file for parallel processing
  local scan_result_file="/tmp/scan_result_${process_id}.json"
  
  # Perform the scan
  tmfs scan -vv dir:"$dir" \
    --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
    -t "owner=Gandalf" \
    -t "stack=v1fs,realtime" > "$scan_result_file" 2>/dev/null

  # Check if scan was successful
  if [ ! -s "$scan_result_file" ]; then
    echo "[Scan #$scan_count][PID:$process_id] ⚠️ No scan results for: $dir" | tee -a $LOG_FILE
    rm -f "$scan_result_file" 2>/dev/null
    return 0
  fi

  echo "[Scan #$scan_count][PID:$process_id] [*] Parsing results from: $dir" | tee -a $LOG_FILE
  
  # Parse and process malicious files
  local malicious_count=0
  jq -r '.scanResults[] | select(.scanResult==1) | .fileName' "$scan_result_file" 2>/dev/null | while read -r file; do
    if [ -n "$file" ] && [ -f "$file" ]; then
      echo "[Scan #$scan_count][PID:$process_id] 🚨 Malicious file detected: $file" | tee -a $LOG_FILE
      quarantine_file "$file"
      malicious_count=$((malicious_count + 1))
    elif [ -n "$file" ]; then
      echo "[Scan #$scan_count][PID:$process_id] ⚠️ File not found: $file" | tee -a $LOG_FILE
    fi
  done
  
  if [ $malicious_count -gt 0 ]; then
    echo "[Scan #$scan_count][PID:$process_id] 🎯 Found and quarantined $malicious_count malicious file(s) in: $dir" | tee -a $LOG_FILE
  fi
  
  # Clean up temporary scan result file
  rm -f "$scan_result_file" 2>/dev/null
}

# Function to perform parallel recursive scan
perform_parallel_recursive_scan() {
  local scan_count="$1"
  local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  
  echo "[$TIMESTAMP] 🔍 [Scan #$scan_count] Starting parallel recursive directory scan..." | tee -a $LOG_FILE
  
  # Get all directories recursively, excluding quarantine
  local total_dirs=0
  local scanned_dirs=0
  local current_jobs=0
  local max_parallel=$MAX_PARALLEL_SCANS
  
  # Count total directories first (excluding quarantine)
  total_dirs=$(find "$SCAN_PATH" -type d | grep -v "$QUARANTINE_DIR" | wc -l)
  echo "[Scan #$scan_count] 📊 Found $total_dirs directories to scan (excluding quarantine)" | tee -a $LOG_FILE
  
  # Scan directories in parallel using a simpler approach
  find "$SCAN_PATH" -type d | grep -v "$QUARANTINE_DIR" | while IFS= read -r dir; do
    scanned_dirs=$((scanned_dirs + 1))
    local process_id=$$
    
    # Start parallel scan
    scan_directory "$dir" "$scan_count" "$process_id" &
    current_jobs=$((current_jobs + 1))
    
    echo "[Scan #$scan_count] 🚀 Started parallel scan $current_jobs/$total_dirs: $dir" | tee -a $LOG_FILE
    
    # Limit parallel processes and add rate limiting
    if [ $current_jobs -ge $max_parallel ]; then
      echo "[Scan #$scan_count] ⏸️  Waiting for parallel scans to complete ($current_jobs active)..." | tee -a $LOG_FILE
      wait  # Wait for all background jobs
      current_jobs=0
      
      # Rate limiting delay
      if [ $PARALLEL_DELAY -gt 0 ]; then
        echo "[Scan #$scan_count] ⏱️  Rate limiting: Waiting $PARALLEL_DELAY seconds..." | tee -a $LOG_FILE
        sleep $PARALLEL_DELAY
      fi
    fi
  done
  
  # Wait for remaining background jobs
  if [ $current_jobs -gt 0 ]; then
    echo "[Scan #$scan_count] ⏸️  Waiting for final $current_jobs parallel scans to complete..." | tee -a $LOG_FILE
    wait
  fi
  
  echo "[$TIMESTAMP] ✅ [Scan #$scan_count] Parallel recursive scan complete. Scanned $scanned_dirs directories." | tee -a $LOG_FILE
}

# Function to perform sequential recursive scan (fallback)
perform_sequential_recursive_scan() {
  local scan_count="$1"
  local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  
  echo "[$TIMESTAMP] 🔍 [Scan #$scan_count] Starting sequential recursive directory scan..." | tee -a $LOG_FILE
  
  # Get all directories recursively, excluding quarantine
  local total_dirs=0
  local scanned_dirs=0
  
  # Count total directories first (excluding quarantine)
  total_dirs=$(find "$SCAN_PATH" -type d | grep -v "$QUARANTINE_DIR" | wc -l)
  echo "[Scan #$scan_count] 📊 Found $total_dirs directories to scan (excluding quarantine)" | tee -a $LOG_FILE
  
  # Scan each directory sequentially
  find "$SCAN_PATH" -type d | grep -v "$QUARANTINE_DIR" | while IFS= read -r dir; do
    scanned_dirs=$((scanned_dirs + 1))
    scan_directory "$dir" "$scan_count" "seq"
  done
  
  echo "[$TIMESTAMP] ✅ [Scan #$scan_count] Sequential recursive scan complete. Scanned $scanned_dirs directories." | tee -a $LOG_FILE
}

# Function to perform complete recursive scan with fallback
perform_recursive_scan() {
  local scan_count="$1"
  
  if [ "$ENABLE_PARALLEL" = "true" ]; then
    # Try parallel scanning first
    echo "[Scan #$scan_count] ⚡ Attempting parallel scanning..." | tee -a $LOG_FILE
    if perform_parallel_recursive_scan "$scan_count"; then
      return 0
    else
      echo "[Scan #$scan_count] ⚠️ Parallel scanning failed, falling back to sequential..." | tee -a $LOG_FILE
      ENABLE_PARALLEL=false  # Disable parallel for this scan cycle
      perform_sequential_recursive_scan "$scan_count"
    fi
  else
    # Use sequential scanning
    perform_sequential_recursive_scan "$scan_count"
  fi
}

# Function to check if NFS mount is still valid
check_mount() {
  if ! mountpoint -q "$SCAN_PATH"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ NFS mount lost, attempting to remount..." | tee -a $LOG_FILE
    mount -o nolock -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
    if [ $? -ne 0 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to remount NFS share." | tee -a $LOG_FILE
      return 1
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ NFS share remounted successfully." | tee -a $LOG_FILE
  fi
  return 0
}

# Function to monitor system resources
monitor_resources() {
  local scan_count="$1"
  local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
  local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
  
  echo "[Scan #$scan_count] 📊 System Resources - CPU: ${cpu_usage}%, Memory: ${memory_usage}%" | tee -a $LOG_FILE
  
  # Warn if resources are high
  if [ "${cpu_usage%.*}" -gt 80 ]; then
    echo "[Scan #$scan_count] ⚠️ High CPU usage detected: ${cpu_usage}%" | tee -a $LOG_FILE
  fi
  
  if [ "${memory_usage%.*}" -gt 80 ]; then
    echo "[Scan #$scan_count] ⚠️ High memory usage detected: ${memory_usage}%" | tee -a $LOG_FILE
  fi
}

# Main continuous scanning loop
main_scan_loop() {
  local scan_count=0
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Starting continuous scanning loop (every ${SCAN_INTERVAL} seconds)..." | tee -a $LOG_FILE
  
  while true; do
    scan_count=$((scan_count + 1))
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$TIMESTAMP] 🔄 [Scan #$scan_count] Beginning scan cycle..." | tee -a $LOG_FILE
    
    # Check if mount is still valid
    if ! check_mount; then
      echo "[$TIMESTAMP] ❌ [Scan #$scan_count] Mount check failed, waiting ${SCAN_INTERVAL} seconds before retry..." | tee -a $LOG_FILE
      sleep $SCAN_INTERVAL
      continue
    fi
    
    # Monitor system resources
    monitor_resources "$scan_count"
    
    # Perform the recursive scan
    perform_recursive_scan "$scan_count"
    
    echo "[$TIMESTAMP] ⏰ [Scan #$scan_count] Scan complete. Waiting ${SCAN_INTERVAL} seconds until next scan..." | tee -a $LOG_FILE
    echo "[$TIMESTAMP] 📁 Quarantined files are stored in: $QUARANTINE_DIR" | tee -a $LOG_FILE
    echo "---" | tee -a $LOG_FILE
    
    # Wait for next scan cycle
    sleep $SCAN_INTERVAL
  done
}

# Signal handler for graceful shutdown
cleanup() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛑 Received shutdown signal. Cleaning up..." | tee -a $LOG_FILE
  
  # Kill any remaining background processes
  jobs -p | xargs -r kill 2>/dev/null
  
  # Clean up temporary scan result files
  rm -f /tmp/scan_result_*.json 2>/dev/null
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Continuous scanning stopped." | tee -a $LOG_FILE
  exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start the continuous scanning system
if initialize_scan; then
  main_scan_loop
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to initialize scanning system. Exiting." | tee -a $LOG_FILE
  exit 1
fi
