#!/bin/bash

##################################################
# TechCorp Network Health Checker
# Purpose: Verify connectivity to all infrastructure servers
# Author: samiulAsumel
##################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# TechCorp server inventory
declare -A SERVERS=(
	["dev-web"]="192.168.56.101"
	["dev-db"]="192.168.56.102"
	["stage-web"]="192.168.56.103"
	["stage-db"]="192.168.56.104"
	["prod-web"]="192.168.56.105"
	["cicd-jenkins"]="192.168.56.106"
)

# Critical services to check (hostname:port)
declare -A SERVICES=(
	["dev-web:80"]="HTTP"
	["dev-db:3306"]="MySQL"
	["cicd-jenkins:22"]="SSH"
	["cicd-jenkins:8080"]="Jenkins"
)

echo "==========================================="
echo "=== TechCorp Network Health Report ==="
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==========================================="
echo ""

# Function: Check if host is reachable
check_ping() {
	local hostname=$1
	local ip=$2

	if ping -c 2 -W 2 "$ip" &>/dev/null; then
		echo -e "${GREEN}✓${NC} $hostname ($ip) is reachable."
		return 0
	else
		echo -e "${RED}✗${NC} $hostname ($ip) is not reachable."
		return 1
	fi
}

# Function: Check if port is open
check_port() {
	local ip=$1
	local port=$2
	local service=$3

	if nc -zw 2 "$ip" "$port" 2>/dev/null; then
		echo -e "${GREEN}✓ Port $port for $service is open on $ip.${NC}"
		return 0
	else
		echo -e "${RED}✗ Port $port for $service is closed on $ip.${NC}"
		return 1
	fi
}

# Check all servers
echo "--- Server Connectivity ---"
reachable=0
total_servers=${#SERVERS[@]}

for hostname in "${!SERVERS[@]}"; do
	if check_ping "$hostname" "${SERVERS[$hostname]}"; then
		((reachable++))
	fi
done

echo ""
echo "--- Critical Services ---"

for service_key in "${!SERVICES[@]}"; do
	# Split "hostname:port" into variables
	IFS=':' read -r hostname port <<<"$service_key"
	ip="${SERVERS[$hostname]}"
	service_name="${SERVICES[$service_key]}"

	if [[ -n "$ip" ]]; then
		check_port "$ip" "$port" "$service_name"
	fi
done

echo ""
echo "==========================================="
echo "Summary: $reachable out of $total_servers servers are reachable."
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==========================================="

# Exit with error if any server down
if [[ $reachable -lt $total_servers ]]; then
	exit 1
fi

exit 0