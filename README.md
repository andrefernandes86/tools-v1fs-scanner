# 🧹 Trend Micro Vision One File Security – NFS Malware Quarantine

This Docker container uses the **Trend Micro Vision One File Security CLI** to scan files stored in an NFS share and automatically quarantine any file identified as malicious.

> ⚠️ This container mounts an NFS share from inside using `--privileged`. Use only in secure, trusted environments.

---

## 🔧 What It Does

- Mounts a remote NFS share from inside the container
- Scans the mounted directory using Trend Micro Vision One File Security CLI
- Shows real-time scan output
- Parses scan results to find malicious files
- **Quarantines malicious files** by moving them to a secure quarantine directory
- Changes file extensions to `.quarantine` to prevent execution
- Sets restrictive permissions (read-only) to prevent accidental execution
- Logs all quarantine actions and results

---

## 📁 Default Configuration

| Variable         | Description                                           | Default                               |
|------------------|-------------------------------------------------------|---------------------------------------|
| `TMFS_API_KEY`   | Vision One API Key                                    | Injected at build time                |
| `NFS_SERVER`     | IP address of the NFS server                          | `192.168.200.10`                      |
| `NFS_SHARE`      | Exported NFS directory                                | `/mnt/nfs_share`                      |
| `SCAN_PATH`      | Mount point inside the container                      | `/mnt/scan`                           |
| `QUARANTINE_DIR` | Quarantine directory                                  | `/mnt/scan/quarantine`                |
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

---

## 📝 What You'll See

Example output:

```log
[2025-07-01 19:27:26] Creating quarantine directory...
[2025-07-01 19:27:26] Mounting NFS share 192.168.200.10:/mnt/nfs_share to /mnt/scan...
[2025-07-01 19:27:26] 🔍 Starting recursive directory scan...
[+] Scanning directory: /mnt/scan
🚨 Malicious file detected: /mnt/scan/eicar.exe
✅ Quarantined: /mnt/scan/eicar.exe -> /mnt/scan/quarantine/eicar_20250701_192726.quarantine
   Original location: /mnt/scan
   Original extension: exe
   New permissions: -r--------
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

## ✅ Best Practice (Alternative)

Mount the NFS share on the host and pass it into the container:

```bash
sudo mount -t nfs -o nolock 192.168.200.10:/mnt/nfs_share /mnt/scan

docker run --rm -v /mnt/scan:/mnt/scan tmfs-cleaner-nfs
```

This avoids requiring `--privileged`.

---

## 👤 Maintainer

Built for secure environments where automated malware quarantine is required.  
Owner: **Gandalf** 🧙‍♂️
