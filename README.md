# 🧹 V1FS Cleaner with NFS Integration

This Docker container runs the [Trend Micro File Security (TMFS) CLI](https://docs.trendmicro.com/en-us/documentation/article/trend-vision-one-deploying-cli) to scan files located on an NFS share and automatically delete any file identified as malicious.

> ⚠️ **Warning:** This container runs in `--privileged` mode and mounts an NFS share from inside the container. Use it in secure environments only.

---

## 🔧 What It Does

- Mounts a remote NFS share from inside the container
- Scans the mounted directory using TMFS CLI
- Parses scan results (`scanResults[].fileName`)
- Deletes files flagged as malicious (`scanResult == 1`)
- Logs actions and errors to `/tmp/deletion_log.txt`

---

## 📁 Default Configuration

| Variable         | Description                                           | Default                               |
|------------------|-------------------------------------------------------|---------------------------------------|
| `TMFS_API_KEY`   | Trend Micro Vision One API Key                       | Injected at build time (`--build-arg`) |
| `NFS_SERVER`     | IP address of the NFS server                         | `192.168.200.200`                     |
| `NFS_SHARE`      | Exported path from the NFS server                    | `/mnt/nas/malicious-files`           |
| `SCAN_PATH`      | Mount point inside the container                     | `/mnt/scan`                           |
| `LOG_FILE`       | Path to the operation log                            | `/tmp/deletion_log.txt`              |
| `SCAN_LOG`       | TMFS scan result output (JSON)                       | `/tmp/scan_result.json`              |

---

## 🚀 How to Build

Clone the repo and build the Docker image with your API key:

```bash
docker build \
  --build-arg TMFS_API_KEY=your_real_api_key \
  -t tmfs-cleaner-nfs .
```

---

## 🏃 How to Run

The container must be run with `--privileged` to mount the NFS share:

```bash
docker run --rm --privileged tmfs-cleaner-nfs
```

This will:
- Mount the NFS share at `/mnt/scan`
- Run the scan
- Delete any flagged files
- Log actions and exit

---

## 📝 Example Log Output

Here’s what you'll see inside `/tmp/deletion_log.txt`:

```
[2025-05-21 10:00:00] Mounting NFS share...
[2025-05-21 10:00:01] Starting TMFS scan...
[2025-05-21 10:00:03] Deleted: ./test/eicar-alpine.tar
[2025-05-21 10:00:03] Scan-and-delete cycle complete.
```

---

## 🧠 How It Works

TMFS outputs results like this:

```json
{
  "scanResults": [
    {
      "fileName": "./test/eicar-alpine.tar",
      "scanResult": 1
    }
  ]
}
```

This tool deletes any file where `scanResult == 1`.

---

## 🔐 Security Notes

- **This container deletes files. Use in production only if you're confident in your policies.**
- The API key is baked into the image. For better security:
  - Use Docker secrets
  - Mount credentials at runtime
  - Or refactor to use environment variables instead of `--build-arg`

---

## 📅 Scheduling

To schedule recurring scans, use your host system’s cron:

```cron
*/83 * * * * docker run --rm --privileged tmfs-cleaner-nfs
```

This example runs every 83 minutes (1h23m).

---

## 👤 Maintainer

Built for environments where **Gandalf** is the data owner.  
Author: [Your Name]

---

## 📜 License

This project is open source. You can choose a license that fits your needs (MIT, Apache 2.0, etc).
