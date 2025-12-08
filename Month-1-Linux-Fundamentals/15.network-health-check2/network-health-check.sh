#!/bin/bash

##################################################
# Script Name: network-health-check.sh
# Author: samiulAsumel
# Purpose: Quick network diagnostics for TechCorp servers
##################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Banner
echo "==================================================="
echo "Network Health Check Script"
echo "==================================================="
echo ""

# 1. Check primary interface
echo -e "${YELLOW}[1] Checking primary interface...${NC}"
primary_interface=$(ip route | grep default | awk '{print $5}' | head -1)
if ip link show "$primary_interface" | grep -q "UP"; then
	echo -e "${GREEN}✓ Interface $primary_interface is UP.${NC}"
	ip addr show "$primary_interface" | grep "inet " | awk '{print "  IP: " $2}'
else
	echo -e "${RED}✗ Interface $primary_interface is DOWN!${NC}"
fi
echo ""

# 2. Check gateway connectivity
echo -e "${YELLOW}[2] Checking default gateway...${NC}"
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -1)
if ping -c 2 -W 2 "$gateway_ip" &>/dev/null; then
	echo -e "${GREEN}✓ Gateway $gateway_ip is reachable.${NC}"
else
	echo -e "${RED}✗ Gateway $gateway_ip is NOT reachable!${NC}"
fi
echo ""

# 3. Check DNS resolution
echo -e "${YELLOW}[3] Checking DNS resolution...${NC}"
if ping -c 1 -W 2 google.com &>/dev/null; then
	echo -e "${GREEN}✓ DNS resolution is working.${NC}"
else
	echo -e "${RED}✗ DNS resolution is NOT working!${NC}"
fi
echo ""

# 4. Check internet connectivity
echo -e "${YELLOW}[4] Checking internet connectivity...${NC}"
if ping -c 5 -W 3 8.8.8.8 &>/dev/null; then
	echo -e "${GREEN}✓ Internet connectivity is working.${NC}"
else
	echo -e "${RED}✗ Internet connectivity is NOT working!${NC}"
fi
echo ""

# 5. Check listening services
echo -e "${YELLOW}[5] Checking listening services...${NC}"
listening_services=$(ss -tuln | grep LISTEN)
if [ -n "$listening_services" ]; then
	echo -e "${GREEN}✓ Listening services found:${NC}"
	echo "$listening_services"
else
	echo -e "${RED}✗ No listening services found!${NC}"
fi
echo ""

# 6. Connection statistics
echo -e "${YELLOW}[6] Checking connection statistics...${NC}"
conn_stats=$(ss -s)
echo -e "${GREEN}✓ Connection statistics:${NC}"
echo "$conn_stats"
echo ""

# 7. Network errors
echo -e "${YELLOW}[7] Checking network errors...${NC}"
net_errors=$(netstat -i | awk 'NR>2 {print $1, "RX-ERR:", $4, "TX-ERR:", $8}')
echo -e "${GREEN}✓ Network errors:${NC}"
echo "$net_errors"
echo ""

echo "==================================================="
echo -e "${GREEN}Network Health Check Completed.${NC}"
echo "==================================================="