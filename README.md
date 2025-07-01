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

## 📁 Default Configuration

| Variable         | Description                                           | Default                               |
|------------------|-------------------------------------------------------|---------------------------------------|
| `TMFS_API_KEY`   | Vision One API Key                                    | Injected at build time                |
| `NFS_SERVER`     | IP address of the NFS server                          | `192.168.200.10`                      |
| `NFS_SHARE`      | Exported NFS directory                                | `/mnt/nfs_share`                      |
| `SCAN_PATH`      | Mount point inside the container                      | `/mnt/scan`                           |
| `QUARANTINE_DIR` | Quarantine directory                                  | `/mnt/scan/quarantine`                |
| `SCAN_INTERVAL`  | Scan interval in seconds                              | `30`                                  |
| `LOG_FILE`       | Path to quarantine log                                | `/tmp/deletion_log.txt`              |
| `SCAN_JSON`      | Output from TMFS scan                                 | `/tmp/scan_result.json`              |

---

## 🛠️ Build Instructions

Clone this repository and build the image using your API key:

```bash
docker build \
  --build-arg TMFS_API_KEY=your_real_api_key \
  -t tmfs-cleaner-nfs .
```

---

## 🚀 How to Run

Run the container with `--privileged` to allow in-container NFS mounting:

```bash
docker run --rm --privileged tmfs-cleaner-nfs
```

For continuous operation in production, run in detached mode:

```bash
docker run -d --privileged --name tmfs-scanner tmfs-cleaner-nfs
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

---

## ✅ Best Practice (Alternative)

Mount the NFS share on the host and pass it into the container:

```bash
sudo mount -t nfs -o nolock 192.168.200.10:/mnt/nfs_share /mnt/scan

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

## 👤 Maintainer

Built for secure environments where automated malware quarantine is required.  
Owner: **Gandalf** 🧙‍♂️
