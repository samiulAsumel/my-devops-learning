#!/bin/bash

################################################
# Script Name: package-manager.sh
# Purpose: Maintain consistent package state across servers
# Author: samiulAsumel
################################################

# Configuration
LOGFILE="/var/log/package-manager.log"
REPORT_FILE="/var/log/package-manager-report.txt"
ADMIN_EMAIL="devops@techcorp.com"
SERVER_HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Required packages for DevOps servers
REQUIRED_PACKAGES=("vim" "nano" "curl" "wget" "git" "unzip" "tar" "gzip" "bzip2" "rsync" "htop" "net-tools" "lsof" "telnet" "ncdu" "tree" "jq" "policycoreutils" "selinux-policy" "selinux-policy-targeted" "chrony"
"gcc" "gcc-c++" "make" "automake" "autoconf" "cmake" "openssl-devel" "libffi-devel" "python3" "python3-pip" "python3-devel" "java-17-openjdk" "java-17-openjdk-devel" "golang" "nodejs" "npm" "maven" "gradle"
"git" "git-lfs" "subversion" "mercurial" "tig" "gh"
"ansible" "terraform" "packer" "salt" "puppet" "chef" "terraform-ls" "terragrunt"
"docker" "docker-compose" "podman" "buildah" "skopeo" "cri-o" "containerd" "vagrant" "qemu-kvm" "libvirt" "virt-manager" "minikube" "kind" "kubectl" "helm" "k9s" "kubectx" "kubens"
"jenkins" "gitlab-runner" "drone-runner" "github-runner" "argo" "argo-workflows" "tektoncd-cli"
"nginx" "httpd" "haproxy" "traefik" "envoy"
"prometheus" "grafana" "node_exporter" "alertmanager" "loki" "fluentd" "filebeat" "metricbeat" "elasticsearch" "kibana"
"postgresql" "mariadb" "mysql" "redis" "mongodb" "influxdb"
"vault" "consul" "etcd" "keycloak"
"awscli" "azure-cli" "google-cloud-sdk" "doctl" "kubeseal" "argocd" "eksctl" "kops"
"nginx-mod-stream" "nginx-mod-http-perl"
"iptables" "firewalld" "fail2ban" "nmap" "tcpdump" "iproute" "iputils" "traceroute"
"zip" "unzip" "p7zip" "screen" "tmux" "expect" "socat" "netcat" "nfs-utils" "cifs-utils" "fuse" "fuse-libs"
"python3-venv" "python3-virtualenv" "virtualenvwrapper"
)

# Logging function
log_message() {
	echo "[$DATE] $1" >> "$LOGFILE"
}

# Banner
log_message "=================================================="
log_message "TechCorp Package Management Script Started"
log_message "Server: $SERVER_HOSTNAME"
log_message "Date: $DATE"
log_message "=================================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root or with sudo privileges." >&2
	log_message "ERROR: Script not run as root. Exiting."
	exit 1
fi

# Step 1: Update package cache
log_message "Step 1: Updating package cache..."
dnf makecache &>> "$LOGFILE"

if [[ $? -eq 0 ]]; then
	log_message "Package cache updated successfully."
else
	log_message "ERROR: Package cache update failed."
fi

# Step 2: Check for security updates
log_message "Step 2: Checking for security updates..."
SECURITY_UPDATES=$(dnf updateinfo list security --available | wc -l)

if [[ $SECURITY_UPDATES -gt 0 ]]; then
	log_message "Found $SECURITY_UPDATES security updates available."
	log_message "Installing security updates..."
	dnf update --security -y &>> "$LOGFILE"

	if [[ $? -eq 0 ]]; then
		log_message "Security updates installed successfully."
	else
		log_message "Some security updates failed to install."
	fi
else
	log_message "System is up-to-date (no security patches needed)."
fi

# Step 3: Install missing required packages
log_message "Step 3: Checking and installing required packages..."
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
	if ! rpm -q "$package" &> /dev/null; then
		MISSING_PACKAGES+=("$package")
	fi
done

if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
	log_message "Installing missing packages: ${MISSING_PACKAGES[*]}"
	dnf install -y "${MISSING_PACKAGES[@]}" &>> "$LOGFILE"

	if [[ $? -eq 0 ]]; then
		log_message "All missing packages installed successfully."
	else
		log_message "Some packages failed to install."
	fi
else
	log_message "All required packages are already installed."
fi

# Step 4: Remove orphaned packages
log_message "Step 4: Removing orphaned packages..."
ORPHANED_PACKAGES=$(dnf autoremove --assumeno 2>/dev/null | grep -c "Will remove")

if [[ $ORPHANED_PACKAGES -gt 0 ]]; then
	log_message "Found $ORPHANED_PACKAGES orphaned packages. Removing..."
	dnf autoremove -y &>> "$LOGFILE"
	log_message "Orphaned packages removed successfully."
else
	log_message "No orphaned packages found."
fi

# Step 5: Check if reboot is required
log_message "Step 5: Checking if system reboot is required..."
if needs-restarting -r &> /dev/null; then
	log_message "No reboot required."
	REBOOT_STATUS="Not Required"
else
	log_message "Reboot recommended for kernel/core updates."
	REBOOT_STATUS="Required"
fi

# Step 6: Generate summary report
log_message "Step 6: Generating summary report..."

INSTALLED_PACKAGES=$(rpm -qa | wc -l)
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
MEMORY_USAGE=$(free -h | awk 'NR==2 {print $3 "/" $2}')
UPTIME=$(uptime -p)

# Create report
REPORT="Package Management Summary Report
==========================================
Server: $SERVER_HOSTNAME
Date: $DATE
------------------------------------------
Total Installed Packages: $INSTALLED_PACKAGES
Disk Usage (Root): $DISK_USAGE
Memory Usage: $MEMORY_USAGE
System Uptime: $UPTIME
Reboot Required: $REBOOT_STATUS
==========================================
"

# Save report to file
echo "$REPORT" > "$REPORT_FILE"

# Print report to console
echo "$REPORT"

# Logging
log_message "TechCorp Package Management Script Completed"
log_message "Log File: $LOGFILE"
log_message "Report File: $REPORT_FILE"
log_message "=================================================="

# Exit with success
exit 0