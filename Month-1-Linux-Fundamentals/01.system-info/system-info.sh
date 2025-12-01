#!/bin/bash

################################################
# System Information Report
# TechCorp Ltd. - DevOps Team
# Purpose: Display critical system information
# Author: samiulAsumel
################################################

echo "=============================="
echo " TECHCORP SYSTEM INFORMATION REPORT "
echo "=============================="
echo ""

echo "Hostname: $(hostnamectl)"
echo "OS Version: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f2 | tr -d '"')"
echo "Kernel Version: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

echo "IP Addresses:"
ip -4 addr show | grep inet  | grep -v 127.0.0.1 | awk '{print " " $2}'
echo ""

echo "Disk Usage:"
df -h | grep -E '^/dev/' |awk '{print " " $1 " " $5 " used"}'
echo ""

echo "Memory Usage:"
free -h | grep Mem | awk '{print " Total: " $2 " Used: " $3 " Free: " $4}'
echo ""

echo "Current Logged-in Users: $(whoami)"
echo "Report Generated on: $(date)"
echo "=============================="