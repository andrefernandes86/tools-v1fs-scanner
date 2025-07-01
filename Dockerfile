FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl tar nfs-common jq && \
    apt-get clean

# Build-time API key
ARG TMFS_API_KEY
ENV TMFS_API_KEY=${TMFS_API_KEY}

# Set environment variables
ENV TMFS_DIR=/opt/tmfs
ENV PATH="$TMFS_DIR:$PATH"
ENV SCAN_PATH=/mnt/scan
ENV LOG_FILE=/tmp/deletion_log.txt
ENV SCAN_JSON=/tmp/scan_result.json
ENV NFS_SERVER=192.168.200.10
ENV NFS_SHARE=/mnt/nfs_share

# Download and extract TMFS CLI
RUN mkdir -p $TMFS_DIR && \
    curl -L https://tmfs-cli.fs-sdk-ue1.xdr.trendmicro.com/tmfs-cli/latest/tmfs-cli_Linux_x86_64.tar.gz \
    -o /tmp/tmfs.tar.gz && \
    tar -xzf /tmp/tmfs.tar.gz -C $TMFS_DIR && \
    rm /tmp/tmfs.tar.gz

# Copy scan script
COPY scan_and_delete.sh /usr/local/bin/scan_and_delete.sh
RUN chmod +x /usr/local/bin/scan_and_delete.sh

# Run the script on container start
CMD ["/usr/local/bin/scan_and_delete.sh"]
