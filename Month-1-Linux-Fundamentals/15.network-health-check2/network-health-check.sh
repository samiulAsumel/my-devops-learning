#!/bin/bash

##################################################
# Script Name: network-health-check.sh
# Author: samiulAsumel
# Purpose: Quick network diagnostics for TechCorp servers
##################################################

# Color codes for output
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
nc='\033[0m' # No Color

# Banner
echo "==================================================="
echo "Network Health Check Script"
echo "==================================================="
echo ""

# 1. Check primary interface
echo -e "${yellow}Checking primary interface...${nc}"
primary_interface=$(ip route | grep default | awk '{print $5}' | head -1)
if ip link show "$primary_interface" | grep -q "UP"; then
	echo -e "${green}Interface $primary_interface is UP.${nc}"
	ip addr show "$primary_interface" | grep "inet " | awk '{print " IP: " $2}'
else
	echo -e "${red}Interface $primary_interface id DOWN!${nc}"
fi
echo ""