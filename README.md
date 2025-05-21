
# 🧹 Trend Micro Vision One File Security – NFS Malware Cleaner

This Docker container uses the **Trend Micro Vision One File Security CLI** to scan files stored in an NFS share and automatically delete any file identified as malicious.

> ⚠️ This container mounts an NFS share from inside using `--privileged`. Use only in secure, trusted environments.

---

## 🔧 What It Does

- Mounts a remote NFS share from inside the container
- Scans the mounted directory using Trend Micro Vision One File Security CLI
- Shows real-time scan output
- Parses scan results to find malicious files
- Deletes those malicious files
- Logs actions and results

---

## 📁 Default Configuration

| Variable         | Description                                           | Default                               |
|------------------|-------------------------------------------------------|---------------------------------------|
| `TMFS_API_KEY`   | Vision One API Key                                    | Injected at build time                |
| `NFS_SERVER`     | IP address of the NFS server                          | `192.168.200.200`                     |
| `NFS_SHARE`      | Exported NFS directory                                | `/mnt/nas/malicious-files`           |
| `SCAN_PATH`      | Mount point inside the container                      | `/mnt/scan`                           |
| `LOG_FILE`       | Path to deletion log                                  | `/tmp/deletion_log.txt`              |
| `SCAN_OUTPUT`    | Output from TMFS scan                                 | `/tmp/scan_output.txt`               |

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
[2025-05-21 16:00:00] Mounting NFS share 192.168.200.200:/mnt/nas/malicious-files to /mnt/scan...
[2025-05-21 16:00:01] Running TMFS scan on /mnt/scan...
Scanning: /mnt/scan/js_crypto_miner.html
Malicious: /mnt/scan/js_crypto_miner.html
Deleted: /mnt/scan/js_crypto_miner.html
Scan complete.
```

All actions and scan results are logged to `/tmp/deletion_log.txt`.

---

## ✅ Best Practice (Alternative)

Mount the NFS share on the host and pass it into the container:

```bash
sudo mount -t nfs -o nolock 192.168.200.200:/mnt/nas/malicious-files /mnt/scan

docker run --rm -v /mnt/scan:/mnt/scan tmfs-cleaner-nfs
```

This avoids requiring `--privileged`.

---

## 👤 Maintainer

Built for secure environments where automated malware cleanup is required.  
Owner: **Gandalf** 🧙‍♂️  
