FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl tar nfs-common jq && \
    apt-get clean

# Build-time API key (inject with --build-arg)
ARG TMFS_API_KEY
ENV TMFS_API_KEY=${TMFS_API_KEY}

# Runtime environment settings
ENV TMFS_DIR=/opt/tmfs
ENV PATH="$TMFS_DIR:$PATH"
ENV SCAN_PATH=/mnt/scan
ENV SCAN_LOG=/tmp/scan_result.json
ENV LOG_FILE=/tmp/deletion_log.txt
ENV NFS_SERVER=192.168.200.200
ENV NFS_SHARE=/mnt/nas/malicious-files

# Download and install TMFS CLI
RUN mkdir -p $TMFS_DIR && \
    curl -L https://tmfs-cli.fs-sdk-ue1.xdr.trendmicro.com/tmfs-cli/latest/tmfs-cli_Linux_x86_64.tar.gz \
      -o /tmp/tmfs.tar.gz && \
    tar -xzf /tmp/tmfs.tar.gz -C $TMFS_DIR && \
    rm /tmp/tmfs.tar.gz

# Create the scan-and-delete script
RUN mkdir -p /usr/local/bin && \
    cat << 'EOF' > /usr/local/bin/scan_and_delete.sh
#!/bin/sh
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Mounting NFS share..." >> $LOG_FILE
mkdir -p $SCAN_PATH
mount -t nfs $NFS_SERVER:$NFS_SHARE $SCAN_PATH
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] Failed to mount NFS share." >> $LOG_FILE
  exit 1
fi

echo "[$TIMESTAMP] Starting TMFS scan..." >> $LOG_FILE
tmfs scan \
  --endpoint antimalware.us-1.cloudone.trendmicro.com:443 \
  dir:$SCAN_PATH \
  --tag "owner=Gandalf" \
  --tag "stack=v1fs, schedulescan" \
  --output $SCAN_LOG \
  --output-format json

if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] TMFS scan failed." >> $LOG_FILE
  exit 1
fi

# Validate JSON
if ! jq empty $SCAN_LOG 2>/dev/null; then
  echo "[$TIMESTAMP] Invalid JSON from TMFS." >> $LOG_FILE
  exit 1
fi

# Delete each file flagged as malware
jq -r '.scanResults[] | select(.scanResult==1) | .fileName' $SCAN_LOG | while read -r filepath; do
  if [ -n "$filepath" ] && [ -f "$filepath" ]; then
    rm -f "$filepath"
    if [ $? -eq 0 ]; then
      echo "[$TIMESTAMP] Deleted: $filepath" >> $LOG_FILE
    else
      echo "[$TIMESTAMP] Failed to delete: $filepath" >> $LOG_FILE
    fi
  else
    echo "[$TIMESTAMP] File not found or empty path: $filepath" >> $LOG_FILE
  fi
done

echo "[$TIMESTAMP] Scan-and-delete cycle complete." >> $LOG_FILE
EOF

RUN chmod +x /usr/local/bin/scan_and_delete.sh

# Entry point: run the scan script on container start
CMD ["/usr/local/bin/scan_and_delete.sh"]
