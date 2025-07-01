# 🧹 Trend Micro Vision One File Security – NFS Malware Quarantine

This Docker container uses the **Trend Micro Vision One File Security CLI** to continuously scan files stored in an NFS share and automatically quarantine any file identified as malicious.

> ⚠️ This container mounts an NFS share from inside using `--privileged`. Use only in secure, trusted environments.

---

## 🔧 What It Does

- Mounts a remote NFS share from inside the container
- **Continuously scans the mounted directory** every 30 seconds using Trend Micro Vision One File Security CLI
- **Performs recursive scanning** of all subdirectories and nested folders
- Shows real-time scan output with scan cycle numbering
- Parses scan results to find malicious files
- **Quarantines malicious files** by moving them to a secure quarantine directory
- Changes file extensions to `.quarantine` to prevent execution
- Sets restrictive permissions (read-only) to prevent accidental execution
- **Auto-remounts NFS share** if connection is lost
- Logs all quarantine actions and results
- **Graceful shutdown** with signal handling

---

## ⚙️ **REQUIRED CONFIGURATION**

**⚠️ IMPORTANT: You MUST configure these settings before using this tool!**

### **1. API Key Configuration**
You need a valid **Trend Micro Vision One File Security API Key**:

```bash
# Get your API key from Trend Micro Vision One File Security Portal
# Go to: https://portal.xdr.trendmicro.com/
# Navigate to: File Security > API Keys
# Create a new API key with appropriate permissions
```

### **2. NFS Share Configuration**
You need to specify your **NFS server and share path**:

```bash
# Example NFS configurations:
NFS_SERVER=192.168.1.100
NFS_SHARE=/mnt/shared_files

# Or for a different setup:
NFS_SERVER=10.0.0.50
NFS_SHARE=/exports/malware_scan
```

---

## 📁 Default Configuration

| Variable         | Description                                           | Default                               | **Required?** |
|------------------|-------------------------------------------------------|---------------------------------------|---------------|
| `TMFS_API_KEY`   | **Vision One API Key**                                | **MUST BE PROVIDED**                  | **YES**       |
| `NFS_SERVER`     | **IP address of the NFS server**                      | `192.168.200.10`                      | **YES**       |
| `NFS_SHARE`      | **Exported NFS directory**                            | `/mnt/nfs_share`                      | **YES**       |
| `SCAN_PATH`      | Mount point inside the container                      | `/mnt/scan`                           | No            |
| `QUARANTINE_DIR` | Quarantine directory                                  | `/mnt/scan/quarantine`                | No            |
| `SCAN_INTERVAL`  | Scan interval in seconds                              | `30`                                  | No            |
| `ENABLE_PARALLEL`| Enable parallel directory scanning                    | `true`                                | No            |
| `MAX_PARALLEL_SCANS` | Maximum parallel scans                            | `3`                                   | No            |
| `PARALLEL_DELAY` | Delay between parallel requests (seconds)            | `1`                                   | No            |
| `LOG_FILE`       | Path to quarantine log                                | `/tmp/deletion_log.txt`              | No            |
| `SCAN_JSON`      | Output from TMFS scan                                 | `/tmp/scan_result.json`              | No            |

---

## 🛠️ **STEP-BY-STEP SETUP INSTRUCTIONS**

### **Step 1: Get Your API Key**
1. Log into [Trend Micro Vision One File Security Portal](https://portal.xdr.trendmicro.com/)
2. Navigate to **File Security** > **API Keys**
3. Create a new API key with **scan permissions**
4. Copy the API key (it looks like: `eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...`)

### **Step 2: Configure Your NFS Share**
1. **Identify your NFS server IP address**
2. **Identify your NFS share path**
3. **Test NFS connectivity**:
   ```bash
   # Test if you can mount the NFS share
   sudo mount -t nfs -o nolock YOUR_NFS_SERVER:YOUR_NFS_SHARE /mnt/test
   ls /mnt/test
   sudo umount /mnt/test
   ```

### **Step 3: Update Configuration Files**

**Option A: Edit the files directly**
```bash
# Edit scan_and_delete.sh
nano scan_and_delete.sh

# Change these lines:
export NFS_SERVER=YOUR_NFS_SERVER_IP
export NFS_SHARE=YOUR_NFS_SHARE_PATH
```

**Option B: Use environment variables (recommended)**
```bash
# Create a .env file
cat > .env << EOF
NFS_SERVER=192.168.1.100
NFS_SHARE=/mnt/shared_files
EOF
```

### **Step 4: Build with Your API Key**
```bash
docker build \
  --build-arg TMFS_API_KEY=your_actual_api_key_here \
  -t tmfs-cleaner-nfs .
```

---

## 🚀 **USAGE EXAMPLES**

### **Example 1: Basic Usage**
```bash
# Build with your API key
docker build \
  --build-arg TMFS_API_KEY=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9... \
  -t tmfs-cleaner-nfs .

# Run the container
docker run --rm --privileged tmfs-cleaner-nfs
```

### **Example 2: Custom NFS Configuration**
```bash
# Build the image
docker build \
  --build-arg TMFS_API_KEY=your_api_key_here \
  -t tmfs-cleaner-nfs .

# Run with custom NFS settings
docker run --rm --privileged \
  -e NFS_SERVER=10.0.0.50 \
  -e NFS_SHARE=/exports/malware_scan \
  tmfs-cleaner-nfs
```

### **Example 3: Production Deployment**
```bash
# Build for production
docker build \
  --build-arg TMFS_API_KEY=your_production_api_key \
  -t tmfs-cleaner-nfs:latest .

# Run in detached mode for continuous operation
docker run -d \
  --privileged \
  --name tmfs-scanner \
  --restart unless-stopped \
  -e NFS_SERVER=192.168.1.100 \
  -e NFS_SHARE=/mnt/shared_files \
  tmfs-cleaner-nfs:latest
```

---

## 📝 What You'll See

Example output from continuous scanning:

```log
[2025-07-01 19:31:08] 🚀 Initializing continuous recursive scan system...
[2025-07-01 19:31:08] Creating quarantine directory...
[2025-07-01 19:31:08] Mounting NFS share 192.168.200.10:/mnt/nfs_share to /mnt/scan...
[2025-07-01 19:31:08] ✅ Initialization complete. Starting continuous monitoring...
[2025-07-01 19:31:08] 🔄 Starting continuous scanning loop (every 30 seconds)...
[2025-07-01 19:31:08] 🔄 [Scan #1] Beginning scan cycle...
[2025-07-01 19:31:08] 🔍 [Scan #1] Starting recursive directory scan...
[Scan #1] 📊 Found 5 directories to scan
[Scan #1] [+] Scanning directory: /mnt/scan
[Scan #1] [+] Scanning directory: /mnt/scan/quarantine
[Scan #1] [+] Scanning directory: /mnt/scan/temp
[Scan #1] [+] Scanning directory: /mnt/scan/temp/temp2
[Scan #1] [+] Scanning directory: /mnt/scan/temp/temp2/temp3
[Scan #1] 🚨 Malicious file detected: /mnt/scan/eicar.com
✅ Quarantined: /mnt/scan/eicar.com -> /mnt/scan/quarantine/eicar_20250701_193109.quarantine
[2025-07-01 19:31:10] ✅ [Scan #1] Recursive scan complete. Scanned 5 directories.
[2025-07-01 19:31:10] ⏰ [Scan #1] Scan complete. Waiting 30 seconds until next scan...
---
[2025-07-01 19:31:40] 🔄 [Scan #2] Beginning scan cycle...
```

All quarantine actions and scan results are logged to `/tmp/deletion_log.txt`.

---

## 🔒 Quarantine Features

### **File Naming Convention:**
- Original files are renamed with timestamp: `filename_YYYYMMDD_HHMMSS.quarantine`
- Example: `eicar.exe` → `eicar_20250701_192726.quarantine`

### **Security Measures:**
- **Extension Change**: All quarantined files get `.quarantine` extension
- **Restrictive Permissions**: Files are set to read-only (400) to prevent execution
- **Timestamped Names**: Prevents filename conflicts and provides audit trail
- **Isolated Directory**: All quarantined files are stored in `/mnt/scan/quarantine`

### **Recovery Process:**
To recover a quarantined file:
1. Navigate to the quarantine directory
2. Change permissions: `chmod 644 filename_YYYYMMDD_HHMMSS.quarantine`
3. Rename file: `mv filename_YYYYMMDD_HHMMSS.quarantine filename.original_extension`

---

## 🔄 Continuous Scanning Features

### **Real-time Monitoring:**
- **30-second intervals**: Scans complete directory structure every 30 seconds
- **Recursive scanning**: Inspects all subdirectories and nested folders
- **Scan cycle tracking**: Each scan is numbered for easy tracking
- **Mount monitoring**: Automatically detects and remounts lost NFS connections

### **⚡ Parallel Scanning (NEW):**
- **Directory-level parallelism**: Scans multiple directories simultaneously
- **Configurable concurrency**: Up to 3 parallel scans by default (adjustable)
- **Rate limiting protection**: Built-in delays to prevent API throttling
- **Automatic fallback**: Falls back to sequential scanning if parallel fails
- **Resource monitoring**: Tracks CPU and memory usage during scans
- **Process isolation**: Each parallel scan uses unique temporary files

### **🚫 Quarantine Exclusion (NEW):**
- **Automatic exclusion**: Quarantine directory is never scanned
- **Subdirectory protection**: All quarantine subdirectories are excluded
- **Performance optimization**: Reduces scan time by skipping quarantined files
- **Prevents re-scanning**: Avoids scanning already quarantined malicious files

### **Robust Error Handling:**
- **Graceful shutdown**: Responds to SIGTERM and SIGINT signals
- **Mount recovery**: Automatically remounts NFS if connection is lost
- **Permission handling**: Falls back to copy-then-delete if direct move fails
- **Scan continuation**: Continues scanning even if individual files fail

### **Performance Optimizations:**
- **Directory counting**: Shows total directories found before scanning
- **Progress tracking**: Reports scanned directories and found malicious files
- **Efficient parsing**: Uses jq for fast JSON parsing of scan results
- **Error suppression**: Redirects stderr to avoid log clutter
- **Resource monitoring**: Warns about high CPU/memory usage

---

## ✅ Best Practice (Alternative)

Mount the NFS share on the host and pass it into the container:

```bash
# Mount your NFS share
sudo mount -t nfs -o nolock YOUR_NFS_SERVER:YOUR_NFS_SHARE /mnt/scan

# Run without privileged mode
docker run --rm -v /mnt/scan:/mnt/scan tmfs-cleaner-nfs
```

This avoids requiring `--privileged`.

---

## 🛑 Stopping the Scanner

To stop the continuous scanner gracefully:

```bash
# If running in foreground
Ctrl+C

# If running in background
docker stop tmfs-scanner

# Or send signal directly
docker kill --signal=SIGTERM tmfs-scanner
```

---

## ❌ **TROUBLESHOOTING**

### **Common Issues:**

**1. "Invalid token or key" Error**
- ❌ **Problem**: API key is invalid or expired
- ✅ **Solution**: Get a new API key from Trend Micro Vision One File Security Portal

**2. "Failed to mount NFS share" Error**
- ❌ **Problem**: NFS server is unreachable or share doesn't exist
- ✅ **Solution**: Verify NFS server IP and share path are correct

**3. "Permission denied" Errors**
- ❌ **Problem**: NFS share permissions are too restrictive
- ✅ **Solution**: Check NFS server permissions and user access

**4. Container exits immediately**
- ❌ **Problem**: Missing API key or NFS configuration
- ✅ **Solution**: Ensure API key is provided and NFS settings are correct

### **Testing Your Configuration:**
```bash
# Test NFS connectivity
sudo mount -t nfs -o nolock YOUR_NFS_SERVER:YOUR_NFS_SHARE /mnt/test
ls /mnt/test
sudo umount /mnt/test

# Test API key (if you have curl)
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://antimalware.us-1.cloudone.trendmicro.com:443/api/v1/health
```

---

## 👤 Maintainer

Built for secure environments where automated malware quarantine is required.  
Owner: **Gandalf** 🧙‍♂️
