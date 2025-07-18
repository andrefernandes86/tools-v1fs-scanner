#!/bin/bash

# =============================================================================
# TREND MICRO VISION ONE FILE SECURITY - NFS MALWARE QUARANTINE
# Setup Script
# =============================================================================

set -e

echo "🧹 Trend Micro Vision One File Security - NFS Malware Quarantine"
echo "=================================================================="
echo ""
echo "This script will help you configure the malware scanner for your environment."
echo ""

# Check if config.env already exists
if [ -f "config.env" ]; then
    echo "⚠️  config.env already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled. Existing config.env preserved."
        exit 0
    fi
fi

echo ""
echo "📋 REQUIRED CONFIGURATION"
echo "=========================="
echo ""

# Get API Key
echo "🔑 STEP 1: Trend Micro Vision One API Key"
echo "-------------------------------------------"
echo "You need a valid API key from Trend Micro Vision One File Security."
echo "Get it from: https://portal.xdr.trendmicro.com/ > File Security > API Keys"
echo ""
read -p "Enter your API key: " API_KEY

if [ -z "$API_KEY" ]; then
    echo "❌ API key is required. Setup cancelled."
    exit 1
fi

# Get NFS Server
echo ""
echo "🖥️  STEP 2: NFS Server Configuration"
echo "------------------------------------"
echo "Enter the IP address of your NFS server."
echo ""
read -p "Enter NFS server IP address: " NFS_SERVER

if [ -z "$NFS_SERVER" ]; then
    echo "❌ NFS server IP is required. Setup cancelled."
    exit 1
fi

# Get NFS Share
echo ""
echo "📁 STEP 3: NFS Share Path"
echo "--------------------------"
echo "Enter the exported directory path on your NFS server."
echo "Example: /mnt/shared_files"
echo ""
read -p "Enter NFS share path: " NFS_SHARE

if [ -z "$NFS_SHARE" ]; then
    echo "❌ NFS share path is required. Setup cancelled."
    exit 1
fi

# Optional scan interval
echo ""
echo "⏰ STEP 4: Scan Interval (Optional)"
echo "-----------------------------------"
echo "How often should the scanner run? (in seconds)"
echo "Default: 30 seconds"
echo ""
read -p "Enter scan interval (press Enter for default 30): " SCAN_INTERVAL
SCAN_INTERVAL=${SCAN_INTERVAL:-30}

# Create config.env
echo ""
echo "📝 Creating configuration file..."
cat > config.env << EOF
# =============================================================================
# TREND MICRO VISION ONE FILE SECURITY - NFS MALWARE QUARANTINE
# Generated by setup.sh on $(date)
# =============================================================================

# Required Settings
TMFS_API_KEY=$API_KEY
NFS_SERVER=$NFS_SERVER
NFS_SHARE=$NFS_SHARE

# Optional Settings
SCAN_INTERVAL=$SCAN_INTERVAL
SCAN_PATH=/mnt/scan
QUARANTINE_DIR=/mnt/scan/quarantine
EOF

echo "✅ Configuration file created: config.env"
echo ""

# Test NFS connectivity
echo "🔍 Testing NFS connectivity..."
echo "Attempting to mount $NFS_SERVER:$NFS_SHARE..."

# Create temporary mount point
TEMP_MOUNT="/tmp/nfs_test_$$"
mkdir -p "$TEMP_MOUNT"

if mount -t nfs -o nolock "$NFS_SERVER:$NFS_SHARE" "$TEMP_MOUNT" 2>/dev/null; then
    echo "✅ NFS connection successful!"
    echo "📁 Found $(ls "$TEMP_MOUNT" | wc -l) items in the share"
    umount "$TEMP_MOUNT"
    rmdir "$TEMP_MOUNT"
else
    echo "⚠️  Warning: Could not mount NFS share"
    echo "   This might be due to network issues or permissions"
    echo "   The scanner will attempt to mount it when running"
    rmdir "$TEMP_MOUNT" 2>/dev/null || true
fi

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo "1. Build the Docker image:"
echo "   docker build --build-arg TMFS_API_KEY=$API_KEY -t tmfs-cleaner-nfs ."
echo ""
echo "2. Run the scanner:"
echo "   docker run --rm --privileged --env-file config.env tmfs-cleaner-nfs"
echo ""
echo "3. For production (detached mode):"
echo "   docker run -d --privileged --name tmfs-scanner --restart unless-stopped --env-file config.env tmfs-cleaner-nfs"
echo ""
echo "📖 For more information, see README.md"
echo "" 