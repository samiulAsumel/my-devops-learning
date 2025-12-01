#!/bin/bash

######################################
# Permission Audit Script
# Author samiulAsumel
######################################

AUDIT_LOG="/var/log/permission-audit.log"
# Use sudo tee for logging if /var/log is not writable
LOG_CMD="tee -a"
if [[ "$AUDIT_LOG" == /var/* ]] && [[ ! -w "$(dirname "$AUDIT_LOG")" ]]; then
    LOG_CMD="sudo tee -a"
fi

SCAN_PATH=(
    "/company-data"
    "/etc"
    "/var/log"
    "/var/www"
    "/opt"
    "/usr/local"
    "/"
)

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

echo "=== TechCorp Permission Audit ===" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
echo "Date: $(date)" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
echo "" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null

# Function: Check world-writable files (security risk)
check_world_writable_files() {
    local path=$1
    echo "[WARNING] World-writable files found:" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    # Exclude special filesystems
    find "$path" -xdev -type f -perm -002 -ls 2>/dev/null | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    echo "" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
}

# Function: Check SUID/SGID files (privilege escalation risk)
check_suid_sgid_files() {
    local path=$1
    echo "[ALERT] SUID/SGID files found:" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    # Check SUID and SGID separately for better visibility
    echo "SUID files:" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    find "$path" -xdev -type f -perm -4000 -ls 2>/dev/null | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    echo "SGID files:" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    find "$path" -xdev -type f -perm -2000 -ls 2>/dev/null | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    echo "" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
}

# Function: Check files without owner (orphaned files)
check_orphaned_files() {
    local path=$1
    echo "[INFO] Orphaned files(no owner) found:" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    find "$path" -xdev \( -nouser -o -nogroup \) -ls 2>/dev/null | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    echo "" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
}

# Function: Check overly permissive directories
check_permissive_dirs() {
    local path=$1
    echo "[WARNING] Overly permissive directories found (777):" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    find "$path" -xdev -type d -perm -777 -ls 2>/dev/null | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    echo "" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
}

# Run Audit
for path in "${SCAN_PATH[@]}"; do
    if [[ -d "$path" && -r "$path" ]]; then
        echo "Scanning: $path" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
        check_world_writable_files "$path"
        check_suid_sgid_files "$path"
        check_orphaned_files "$path"
        check_permissive_dirs "$path"
    else
        echo "WARNING: Cannot access $path (not a directory or no read permission)" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
    fi
done

echo "=== Permission Audit Completed ===" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
echo "Report saved to: $AUDIT_LOG" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null
echo "" | $LOG_CMD "$AUDIT_LOG" 2>/dev/null