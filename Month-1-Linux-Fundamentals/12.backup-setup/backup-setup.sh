#!/bin/bash
# techcorp_backup_setup.sh - Initialize TechCorp Backup Infrastructure

set -euo pipefail

# Configuration
BACKUP_DISKS=("/dev/sdb" "/dev/sdc" "/dev/sdd")
BACKUP_SERVICES=("mysql" "mongodb" "application")
BASE_MOUNT="/backup"
ADMIN_GROUP="backup-admins"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
	echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
	exit 1
}

# Check root privileges
[[ $EUID -ne 0 ]] && error "Must run as root"

log "Starting TechCorp Backup Infrastructure Setup"
echo "=============================================="

# Step 1: Create backup admin group
log "Creating backup admin group..."
if ! getent group "$ADMIN_GROUP" > /dev/null; then
	groupadd "$ADMIN_GROUP"
	log "Group $ADMIN_GROUP created"
else
	log "Group $ADMIN_GROUP already exists"
fi

# Add current user to group
usermod -aG "$ADMIN_GROUP" "$SUDO_USER"
log "User $SUDO_USER added to $ADMIN_GROUP"

# Step 2: Backup fstab
FSTAB_BACKUP="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/fstab "$FSTAB_BACKUP"
log "Backed up fstab to $FSTAB_BACKUP"

# Step 3: Process each disk
for i in "${!BACKUP_DISKS[@]}"; do
	DISK="${BACKUP_DISKS[$i]}"
	SERVICE="${BACKUP_SERVICES[$i]}"
	MOUNT_POINT="$BASE_MOUNT/$SERVICE"
	PARTITION="${DISK}1"
	
	log "Processing disk $DISK for $SERVICE backups..."
	
	# Check if disk exists
	if [[ ! -b "$DISK" ]]; then
		error "Disk $DISK not found!"
	fi
	
	# Check if disk is already partitioned
	if [[ -b "$PARTITION" ]]; then
		log "Partition $PARTITION already exists, skipping partitioning"
	else
		log "Creating partition on $DISK..."
		# Create partition using parted (non-interactive)
		parted -s "$DISK" mklabel gpt
		parted -s "$DISK" mkpart primary ext4 0% 100%
		
		# Wait for partition to be recognized
		sleep 2
		partprobe "$DISK"
		sleep 2
	fi
	
	# Check if file system exists
	if blkid "$PARTITION" | grep -q TYPE; then
		log "File system already exists on $PARTITION"
		FS_TYPE=$(blkid -s TYPE -o value "$PARTITION")
		log "Detected file system: $FS_TYPE"
	else
		log "Creating ext4 file system on $PARTITION..."
		mkfs.ext4 -L "backup-$SERVICE" "$PARTITION"
		log "File system created with label: backup-$SERVICE"
	fi
	
	# Get UUID
	UUID=$(blkid -s UUID -o value "$PARTITION")
	log "UUID: $UUID"
	
	# Create mount point
	if [[ ! -d "$MOUNT_POINT" ]]; then
		mkdir -p "$MOUNT_POINT"
		log "Created mount point: $MOUNT_POINT"
	fi
	
	# Check if already in fstab
	if grep -q "$UUID" /etc/fstab; then
		log "Entry already exists in fstab, skipping"
	else
		log "Adding to fstab..."
		echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noexec  0  2" >> /etc/fstab
		log "Added to fstab"
	fi
	
	# Mount
	if mount | grep -q "$MOUNT_POINT"; then
		log "$MOUNT_POINT already mounted"
	else
		log "Mounting $MOUNT_POINT..."
		mount "$MOUNT_POINT"
		log "Mounted successfully"
	fi
	
	# Create backup directory structure
	log "Creating directory structure..."
	mkdir -p "$MOUNT_POINT"/{daily,weekly,monthly,logs}
	
	# Set permissions
	chown -R root:"$ADMIN_GROUP" "$MOUNT_POINT"
	chmod 770 "$MOUNT_POINT"
	chmod 775 "$MOUNT_POINT"/{daily,weekly,monthly}
	chmod 755 "$MOUNT_POINT/logs"
	
	log "Permissions set for $SERVICE backup volume"
	echo ""
done

# Step 4: Verify all mounts
log "Verifying all backup mounts..."
df -h | grep "$BASE_MOUNT"

# Step 5: Create backup report script
REPORT_SCRIPT="/usr/local/bin/backup_storage_report.sh"
log "Creating storage report script..."

cat > "$REPORT_SCRIPT" << 'EOF'
#!/bin/bash
# Backup Storage Report for TechCorp

echo "================================================"
echo "  TechCorp Backup Storage Report"
echo "  Generated: $(date)"
echo "================================================"
echo ""

echo "📊 Backup Volume Usage:"
df -h | grep /backup | awk '{printf "%-20s %5s used of %5s (%s)\n", $6, $3, $2, $5}'
echo ""

echo "📁 Backup Directory Sizes:"
for service in mysql mongodb application; do
	if [[ -d "/backup/$service" ]]; then
		size=$(du -sh "/backup/$service" 2>/dev/null | cut -f1)
		echo "  $service: $size"
	fi
done
echo ""

echo "📅 Latest Backups:"
for service in mysql mongodb application; do
	if [[ -d "/backup/$service/daily" ]]; then
		latest=$(ls -t "/backup/$service/daily" 2>/dev/null | head -1)
		if [[ -n "$latest" ]]; then
			echo "  $service: $latest"
		fi
	fi
done
echo ""

echo "⚠️  Storage Alerts:"
df -h | grep /backup | awk '{
	usage = substr($5, 1, length($5)-1);
	if (usage > 90) print "  CRITICAL: " $6 " is " $5 " full!";
	else if (usage > 80) print "  WARNING: " $6 " is " $5 " full";
	else print "  OK: " $6 " has sufficient space (" $5 " used)";
}'

echo ""
echo "================================================"
EOF

chmod +x "$REPORT_SCRIPT"
log "Report script created at $REPORT_SCRIPT"

# Step 6: Create weekly cron job for report
log "Setting up weekly storage report..."
CRON_JOB="0 9 * * 1 $REPORT_SCRIPT | mail -s 'TechCorp Weekly Backup Report' devops@techcorp.com"
(crontab -l 2>/dev/null | grep -v "$REPORT_SCRIPT"; echo "$CRON_JOB") | crontab -
log "Weekly report scheduled for Mondays at 9 AM"

# Step 7: Create README
README_FILE="$BASE_MOUNT/README.md"
cat > "$README_FILE" << EOF
# TechCorp Backup Infrastructure

## Overview
This server hosts centralized backups for TechCorp services.

## Backup Volumes

| Service     | Mount Point          | Purpose                    |
|-------------|---------------------|----------------------------|
| MySQL       | /backup/mysql       | Database backups           |
| MongoDB     | /backup/mongodb     | NoSQL database backups     |
| Application | /backup/application | Application files & configs|

## Directory Structure

\`\`\`
/backup/
├── mysql/
│   ├── daily/      (retention: 7 days)
│   ├── weekly/     (retention: 4 weeks)
│   ├── monthly/    (retention: 12 months)
│   └── logs/
├── mongodb/
│   └── [same structure]
└── application/
    └── [same structure]
\`\`\`

## Access Control

- **Group:** backup-admins
- **Permissions:** rwxrwx--- (770)
- **Members:** Check with \`getent group backup-admins\`

## Management Commands

\`\`\`bash
# Check storage usage
df -h | grep /backup

# Generate storage report
/usr/local/bin/backup_storage_report.sh

# Check mount status
mount | grep /backup

# Verify fstab entries
grep /backup /etc/fstab

# Check file system health
sudo fsck -n /dev/sdb1  # (must unmount first)
\`\`\`

## Maintenance Schedule

- **Daily:** Automated backups run at 2 AM
- **Weekly:** Storage report sent Monday 9 AM
- **Monthly:** File system check (first Sunday)
- **Quarterly:** Backup restoration test

## Troubleshooting

### Volume won't mount
\`\`\`bash
# Check if device exists
lsblk

# Verify UUID in fstab
sudo blkid /dev/sdb1
grep sdb1 /etc/fstab

# Manual mount test
sudo mount -v /backup/mysql
\`\`\`

### Permission denied errors
\`\`\`bash
# Check ownership
ls -ld /backup/mysql

# Fix permissions
sudo chown -R root:backup-admins /backup/mysql
sudo chmod 770 /backup/mysql
\`\`\`

### Disk full alerts
\`\`\`bash
# Find large files
sudo du -h /backup/mysql | sort -rh | head -20

# Clean old backups
sudo find /backup/mysql/daily -mtime +7 -delete
\`\`\`

## Contact

For issues, contact: devops@techcorp.com
Documentation: https://wiki.techcorp.com/backup-infrastructure

---
Setup Date: $(date +%Y-%m-%d)
Setup By: $SUDO_USER
Server: $(hostname)
EOF

log "README created at $README_FILE"

# Final summary
echo ""
echo "=============================================="
log "TechCorp Backup Infrastructure Setup Complete!"
echo "=============================================="
echo ""
echo "✅ Created backup volumes for: ${BACKUP_SERVICES[*]}"
echo "✅ All volumes mounted and added to fstab"
echo "✅ Directory structure created"
echo "✅ Permissions configured"
echo "✅ Storage report script installed"
echo "✅ Weekly reports scheduled"
echo ""
echo "📊 Current Status:"
df -h | grep /backup
echo ""
echo "📝 Next Steps:"
echo "  1. Test backup scripts on each volume"
echo "  2. Configure backup retention policies"
echo "  3. Set up monitoring alerts"
echo "  4. Test restore procedures"
echo "  5. Document backup procedures in wiki"
echo ""
echo "🔧 Management:"
echo "  - Run storage report: $REPORT_SCRIPT"
echo "  - View README: cat $README_FILE"
echo "  - Check logs: journalctl -u backup-*"
echo ""
log "Reboot recommended to verify persistent mounts"