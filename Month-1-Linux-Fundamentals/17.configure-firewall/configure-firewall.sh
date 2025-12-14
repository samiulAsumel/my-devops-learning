#!/bin/bash

######################################################
# TechCorp firewall configuration automation script
# Purpose: Configure firewall rules for TechCorp's Linux servers
# Author: samiulAsumel
#######################################################

# Exit on error, undefined variable, or error in a pipeline
set -eou pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/config"
RULES_DIR="$CONFIG_DIR/rules"
LOG_FILE="$PROJECT_ROOT/logs/firewall-setup.log"
ROLES_CONF="$CONFIG_DIR/roles.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Function
log() {
	local level="$1"
	shift
	local message="$*"
	local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
	log "INFO" "$@"
}

log_error() {
	log "ERROR" "$@"
}

log_success() {
	log "SUCCESS" "$@"
}

log_warning() {
	log "WARNING" "$@"
}

# Detect firewall system
detect_firewall() {
	if systemctl is-active --quiet firewalld; then
		echo "firewalld"
	elif command -v ufw &> /dev/null; then
		echo "ufw"
	elif command -v iptables &> /dev/null; then
		echo "iptables"
	else
		echo "none"
	fi
}

# Configure firewalld
configure_firewalld() {
	local role=$1
	local rule_file="$RULES_DIR/${role}_firewalld.rules"

	log_info "Configuring firewalld for role: $role"

	if [[ ! -f "$rule_file" ]]; then
		log_error "Rule file $rule_file not found for role $role"
		return 1
	fi

	# Read and apply rules
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip comment and empty lines
		[[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

		# Parse rule type
		if [[ "$line" =~ ^SERVICE:(.+)$ ]]; then
			local service="${BASH_REMATCH[1]}"
			log_info "Adding service $service"
			sudo firewall-cmd --permanent --zone=public --add-service="$service"

		elif [[ "$line" =~ ^PORT:(.+)/(.+)$ ]]; then
			local port="${BASH_REMATCH[1]}"
			log_info "Adding port $port"
			sudo firewall-cmd --permanent --zone=public --add-port="$port"/tcp

		elif [[ "$line" =~ ^RICH_RULE:(.+)$ ]]; then
			local rule="${BASH_REMATCH[1]}"
			log_info "Adding rich rule $rule"
			sudo firewall-cmd --permanent --zone=public --add-rich-rule="$rule"
		fi
	done < "$rule_file"

	# Reload firewall
	sudo firewall-cmd --reload
	log_success "firewalld configured successfully for role: $role"
}

# Backup current configuration
backup_firewall() {
	local firewall_type=$1
	local backup_dir="$PROJECT_ROOT/backups"
	local timestamp="$(date '+%Y%m%d_%H%M%S')"
	mkdir -p "$backup_dir"

	case $firewall_type in
		firewalld)
			log_info "Backing up firewalld configuration"
			sudo firewall-cmd --list-all > "$backup_dir/firewalld_backup_$timestamp.txt"
			;;
		iptables)
			log_info "Backing up iptables configuration"
			sudo iptables-save > "$backup_dir/iptables_backup_$timestamp.txt"
			;;
		ufw)
			log_info "Backing up ufw configuration"
			sudo ufw status verbose > "$backup_dir/ufw_backup_$timestamp.txt"
			;;
		*)
			log_warning "No recognized firewall system found to backup."
			;;
	esac

	log_success "Firewall configuration backed up successfully"
}

# Verify Configuration
verify_firewall() {
	local firewall_type=$1

	log_info "Verifying firewall configuration for $firewall_type"

	case $firewall_type in
		firewalld)
			sudo firewall-cmd --list-all
			;;
		iptables)
			sudo iptables -L -v -n
			;;
		ufw)
			sudo ufw status verbose
			;;
		*)
			log_warning "No recognized firewall system found to verify."
			;;
	esac
}

# Main Execution
main() {
	log_info "Starting firewall configuration script"

	# Detect firewall system
	FIREWALL_TYPE=$(detect_firewall)

	if [[ "$FIREWALL_TYPE" == "none" ]]; then
		log_error "No supported firewall system detected. Exiting."
		exit 1
	fi

	log_info "Detected firewall system: $FIREWALL_TYPE"

	# Get server role
	echo -e "\n${YELLOW}Please enter the server role (e.g., webserver, dbserver): ${NC}"
	echo "1) webserver"
	echo "2) database"
	echo "3) jenkins"
	echo "4) monitoring"
	echo "5) backup"
	read -rp "Enter your choice: " role_choice

	case $role_choice in
		1) SERVER_ROLE="webserver" ;;
		2) SERVER_ROLE="database" ;;
		3) SERVER_ROLE="jenkins" ;;
		4) SERVER_ROLE="monitoring" ;;
		5) SERVER_ROLE="backup" ;;
		*) log_error "Invalid choice. Exiting."; exit 1 ;;
	esac

	log_info "Selected server role: $SERVER_ROLE"

	# Backup current configuration
	backup_firewall "$FIREWALL_TYPE"

	# Configure firewall
	case $FIREWALL_TYPE in
		firewalld)
			configure_firewalld "$SERVER_ROLE"
			;;
		iptables)
			log_error "iptables configuration not implemented yet."
			;;
		ufw)
			log_error "ufw configuration not implemented yet."
			;;
		*)
			log_error "Unsupported firewall system: $FIREWALL_TYPE"
			exit 1
			;;
	esac

	# Verify configuration
	verify_firewall "$FIREWALL_TYPE"
	log_success "Firewall configuration script completed successfully"
}

# Execute
mkdir -p "$(dirname "$LOG_FILE")"
main "$@"