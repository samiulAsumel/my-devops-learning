#!/bin/bash

################################################
# Script Name: system-audit.sh
# Description: Performs a basic system audit and generates a report.
# Author: samiulAsumel
################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Report header
echo -e "${GREEN}===============================${NC}"
echo -e "${GREEN}TechCorp System Audit Report${NC}"
echo -e "${GREEN}Generated: $(date)${NC}"
echo -e "${GREEN}Server: $(hostname)${NC}"
echo -e "${GREEN}Auditor: samiulAsumel${NC}"
echo -e "${GREEN}Reporting User: $(whoami)${NC}"
echo -e "${GREEN}===============================${NC}"

# Function to check directory and report
check_directory() {
	local directory=$1
	local purpose=$2

	if [ -d "$directory" ]; then
		size=$(du -sh "$directory" 2>/dev/null | cut -f1)
		echo -e "${GREEN}Directory: $directory${NC}"
		echo -e "${GREEN}Size: $size${NC}"
		echo -e "${GREEN}Files: $(find "$directory" -maxdepth 1 -type f 2>/dev/null | wc -l)${NC}"
		echo -e "${GREEN}Subdir: $(find "$directory" -maxdepth 1 -type d 2>/dev/null | wc -l) - 1${NC}"
		echo -e "${GREEN}Most Recent File: $(find "$directory" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- | xargs -r basename)${NC}"
		echo -e "${GREEN}Purpose: $purpose${NC}"
		echo ""
	else
		echo -e "${RED}Directory $directory does not exist.${NC}"
	fi
}

# Check TechCorp directories
echo -e "\n${YELLOW}=== Company Data Structure ===${NC}"
check_directory "/home" "User Data"
check_directory "/etc" "System Configuration"
check_directory "/var/log" "System Logs"
check_directory "/var/www" "Web Content"
check_directory "/opt" "Third-Party Software"
check_directory "/usr/local" "Local Software"

echo -e "\n${YELLOW}=== Application Directories ===${NC}"
check_directory "/var/www/html" "Web Content"
check_directory "/opt/webapp" "Web Application"

echo -e "\n${YELLOW}=== System Directories ===${NC}"
check_directory "/var/log" "System Logs"
check_directory "/var/tmp" "Temporary Files"
check_directory "/etc" "System Configuration"
check_directory "/opt" "Third-Party Software"

# Disk usage summary
echo -e "\n${YELLOW}=== Disk Usage Summary ===${NC}"
df -h / | tail -1 | awk '{print "Root FS: " $3 "/" $2 " used (" $5 " used)"}'

# Recent large files and directories
echo -e "\n${YELLOW}=== Top 5 Largest Files in Company Data ===${NC}"
find /home /opt -type f -exec du -sh {} + | sort -rh | head -5 | awk '{print $2 ": " $1}'

echo -e "${GREEN} Audit Complete!${NC}"