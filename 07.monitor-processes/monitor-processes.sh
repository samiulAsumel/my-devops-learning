#!/bin/bash

# TechCorp Process Monitoring Script
# Purpose: Check critical services and system health
# Author: samiulAsumel

# Configuration
LOG_FILE="/var/log/techcorp/techcorp_process_monitor.log"
ALERT_CPU=80
ALERT_MEM=85

# Ensure log directory exists
sudo mkdir -p /var/log/techcorp
sudo chown devops:devops /var/log/techcorp

# Function: Log with timestamp
log_message() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function: Check if service is running
check_service() {
	local service_name=$1
	if pgrep "$service_name" > /dev/null; then
		log_message "$service_name is running (PID: $(pgrep -o "$service_name"))"
		return 0
	else
		log_message "ALERT: $service_name is NOT running!"
		return 1
	fi
}

# Function: Get CPU usage
get_cpu_usage() {
	top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
}

# Function: Get memory usage percentage
get_mem_usage() {
	free | grep Mem | awk '{print $3/$2 * 100.0}'
}

# Function: Find high CPU processes
find_high_cpu_processes() {
	log_message "Top CPU consuming processes:"
	ps aux --sort=-%cpu | head -11 | tail -10 >> "$LOG_FILE"
}

# Function: Find high memory processes
find_high_mem_processes() {
	log_message "Top memory consuming processes:"
	ps aux --sort=-%mem | head -11 | tail -10 >> "$LOG_FILE"
}

# Main monitoring
log_message "=== TechCorp Process Monitor Starting ==="

# Check critical services
log_message "--- Checking Critical Services ---"
check_service "nginx"
check_service "mysql"
check_service "redis-server"
check_service "techcorp-app"

# Check system resources
log_message "--- Checking System Resources ---"
CPU_USAGE=$(get_cpu_usage)
MEM_USAGE=$(get_mem_usage)

log_message "CPU Usage: ${CPU_USAGE}%"
log_message "Memory Usage: ${MEM_USAGE}%"

# Alert on high usage
if (( $(echo "$CPU_USAGE > $ALERT_CPU" | bc -l) )); then
	log_message "ALERT: High CPU usage detected: ${CPU_USAGE}%"
	find_high_cpu_processes
fi

if (( $(echo "$MEM_USAGE > $ALERT_MEM" | bc -l) )); then
	log_message "ALERT: High memory usage detected: ${MEM_USAGE}%"
	find_high_mem_processes
fi

# Check for zombie processes
ZOMBIES=$(ps aux | awk '{if ($8 == "Z") print $0}' | wc -l)
if [ "$ZOMBIES" -gt 0 ]; then
	log_message "ALERT: $ZOMBIES zombie processes detected!"
fi

# Process count
PROCESS_COUNT=$(ps -e --no-headers | wc -l)
log_message "Total processes running: $PROCESS_COUNT"
log_message "=== TechCorp Process Monitor Completed ==="