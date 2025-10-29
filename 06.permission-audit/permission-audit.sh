#!/bin/bash

######################################
# Permission Audit Script
# Author samiulAsumel
######################################

AUDIT_LOG="/var/log/permission-audit.log"
SCAN_PATH=(
	"/company-data"
	"/etc"
	"/var/log"
	"/var/www"
	"/opt"
	"/usr/local"
)

echo "=== TechCorp Permission Audit ===" | tee -a "$AUDIT_LOG"
echo "Date: $(date)" | tee -a "$AUDIT_LOG"
echo "" | tee -a "$AUDIT_LOG"

# Function: Check world-writable files (security risk)
check_world_writable_files() {
	echo "[WARNING] World-writable files found:" | tee -a "$AUDIT_LOG"
	find "$1" -type f -perm -002 2>/dev/null | tee -a "$AUDIT_LOG"
	echo "" | tee -a "$AUDIT_LOG"
}

# Function: Check SUID/SGID files (privilege escalation risk)
check_suid_sgid_files() {
	echo "[ALERT] SUID/SGID files found:" | tee -a "$AUDIT_LOG"
	find "$1" -type f -perm -4000 -o -perm -2000 2>/dev/null | tee -a "$AUDIT_LOG"
	echo "" | tee -a "$AUDIT_LOG"
}

# Function: Check files without owner (orphaned files)
check_orphaned_files() {
	echo "[INFO] Orphaned files(no owner) found:" | tee -a "$AUDIT_LOG"
	find "$1" -nouser -o -nogroup 2>/dev/null | tee -a "$AUDIT_LOG"
	echo "" | tee -a "$AUDIT_LOG"
}

# Function: Check overly permissive directories
check_permissive_dirs() {
	echo "[WARNING] Overly permissive directories found (777):" | tee -a "$AUDIT_LOG"
	find "$1" -type d -perm -777 2>/dev/null | tee -a "$AUDIT_LOG"
	echo "" | tee -a "$AUDIT_LOG"
}

# Run Audit
for path in "${SCAN_PATH[@]}"; do
	if [ -d "$path" ]; then
		echo "Scanning: $path" | tee -a "$AUDIT_LOG"

		check_world_writable_files "$path"
		check_suid_sgid_files "$path"
		check_orphaned_files "$path"
		check_permissive_dirs "$path"
	fi
done

echo "=== Permission Audit Completed ===" | tee -a "$AUDIT_LOG"
echo "" | tee -a "$AUDIT_LOG"