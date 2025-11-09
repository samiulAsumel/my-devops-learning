#!/bin/bash

################################################
# TechCorp Service Health Monitor
# Author: samiulAsumel
################################################

# Configuration
SERVICES=("httpd" "mariadb" "sshd")
LOG_FILE="/var/log/techcorp-service-monitor.log"
ALERT_EMAIL="devops@techcorp.com"
HOSTNAME=$(hostname)

# Function to check service status
check_service() {
	local service=$1

	if systemctl is-active --quiet "$service"; then
		echo "[$(date)] $service is running." >> "$LOG_FILE"
		return 0
	else
		echo "[$(date)] $service is down!" >> "$LOG_FILE"
		return 1
	fi
}

# Function to restart service
restart_service() {
	local service=$1
	echo "[$(date)] Attempting to restart $service..." >> "$LOG_FILE"

	if systemctl restart "$service"; then
		echo "[$(date)] $service restarted successfully." >> "$LOG_FILE"
		return 0
	else
		echo "[$(date)] Failed to restart $service!" >> "$LOG_FILE"
		return 1
	fi
}

# Function to send alert email
send_alert() {
	local service=$1
	local message="Alert: $service is DOWN on $HOSTNAME at $(date)."

	# Log to file
	echo "$message" >> "$LOG_FILE"
	
	# Send email
	echo "$message" | mail -s "Service Down Alert: $service on $HOSTNAME" "$ALERT_EMAIL"
	echo "[$(date)] Alert email sent for $service." >> "$LOG_FILE"
}

# Main monitoring loop
echo "[$(date)] === Starting Service Health Monitor ===" >> "$LOG_FILE"

for service in "${SERVICES[@]}"; do
	if ! check_service "$service"; then
		send_alert "$service"

		# Try to restart the service
		if restart_service "$service"; then
			echo "[$(date)] $service recovered." >> "$LOG_FILE"
		else
			echo "[$(date)] CRITICAL: $service could not be recovered." >> "$LOG_FILE"
		fi
	fi
done

echo "[$(date)] === Service Health Monitor Completed ===" >> "$LOG_FILE"