FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl tar nfs-common jq && \
    apt-get clean

# API Key passed at build time
ARG TMFS_API_KEY
ENV TMFS_API_KEY=${TMFS_API_KEY}

# Set environment variables
ENV TMFS_DIR=/opt/tmfs
ENV PATH="$TMFS_DIR:$PATH"
ENV SCAN_PATH=/mnt/scan
ENV SCAN_LOG=/tmp/scan_result.json
ENV LOG_FILE=/tmp/deletion_log.txt
ENV NFS_SERVER=192.168.200.200
ENV NFS_SHARE=/mnt/nas/malicious-files

# Download and extract the TMFS CLI
RUN mkdir -p $TMFS_DIR && \
    curl -L https://tmfs-cli.fs-sdk-ue1.xdr.trendmicro.com/tmfs-cli/latest/tmfs-cli_Linux_x86_64.tar.gz \
    -o /tmp/tmfs.tar.gz && \
    tar -xzf /tmp/tmfs.tar.gz -C $TMFS_DIR && \
    rm /tmp/tmfs.tar.gz

# Copy the scan script into the image
COPY scan_and_delete.sh /usr/local/bin/scan_and_delete.sh
RUN chmod +x /usr/local/bin/scan_and_delete.sh

# Set script to run on container start
CMD ["/usr/local/bin/scan_and_delete.sh"]
