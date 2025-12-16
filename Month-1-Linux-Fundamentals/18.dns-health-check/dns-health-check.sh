#!/bin/bash

###############################################
# DNS Health Check Script
# Description: Monitoring DNS server health and report issues.
# Author: samiulAsumel
###############################################

set -euo pipefail

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DNS_SERVER="192.168.1.10"
DOMAIN="techcorp.com"
LOG_FILE="/var/log/dns_health_check.log"
ALERT_EMAIL="devops@techcorp.com"

# Test hostname resolution
TEST_HOSTS=(
	"www.techcorp.com"
	"mail.techcorp.com"
	"ftp.techcorp.com"
	"db.techcorp.com"
	"cicd-jenkins.techcorp.com"
	"mon-prometheus.techcorp.com"
)

# ==========================================
# Function to log messages
# ==========================================
log_message() {
	local message="$1"
	echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# ==========================================
# Function: Check if DNS server is running
# ==========================================
check_dns_service() {
	log_message "${YELLOW}Checking DNS server status...${NC}"

	if systemctl is-active --quiet named; then
		echo -e "${GREEN}✓ DNS server is running.${NC}"
		log_message "DNS server is running."
		return 0
	else
		echo -e "${RED}✗ DNS server is not running!${NC}"
		log_message "DNS server is not running!"
		return 1
	fi
}

# ==========================================
# Function: Check if DNS port is listening
# ==========================================
check_dns_port() {
	log_message "${YELLOW}Checking if DNS is listening on port 53...${NC}"

	if ss -tulnp | grep -q ":53.*named"; then
		echo -e "${GREEN}✓ DNS is listening on port 53.${NC}"
		log_message "DNS port check: OK."
		return 0
	else
		echo -e "${RED}✗ DNS is not listening on port 53!${NC}"
		log_message "DNS port check: FAILED!"
		return 1
	fi
}

# ==========================================
# Function: Test DNS resolution for hostnames
# ==========================================
test_dns_resolution() {
	local hostname="$1"

	log_message "${YELLOW}Testing DNS resolution for ${hostname}...${NC}"

	# Perform DNS query
	result=$(dig @"$DNS_SERVER" "$hostname" +short 2>/dev/null)

	if [[ -n "$result" ]]; then
		echo -e "${GREEN}✓ Resolved ${hostname} to ${result}${NC}"
		log_message "Resolution OK: $hostname -> $result"
		return 0
	else
		echo -e "${RED}✗ Failed to resolve ${hostname}!${NC}"
		log_message "Resolution FAILED for: $hostname"
		return 1
	fi
}

# ==========================================
# Function: Test reverse DNS
# ==========================================
test_reverse_dns() {
	local ip="$1"

	log_message "Testing reverse DNS for ${ip}..."

	result=$(dig @"$DNS_SERVER" -x "$ip" +short 2>/dev/null)

	if [[ -n "$result" ]]; then
		echo -e "${GREEN}✓ Reverse DNS for ${ip} resolved to ${result}${NC}"
		log_message "Reverse DNS OK: $ip -> $result"
		return 0
	else
		echo -e "${RED}✗ Failed to resolve reverse DNS for ${ip}!${NC}"
		log_message "Reverse DNS FAILED for: $ip"
		return 1
	fi
}

# ==========================================
# Function: Check DNS query response time
# ==========================================
check_response_time() {
	local hostname="$1"

	log_message "Checking DNS response time for: $hostname"

	# Measure query time
	query_time=$(dig @"$DNS_SERVER" "$hostname" | grep "Query time:" | awk '{print $4}')

	if [[ -n "$query_time" ]]; then
		if [[ "$query_time" -lt 100 ]]; then
			echo -e "${GREEN}✓ Query time: ${query_time}ms (Excellent)${NC}"
			log_message "Response time OK: ${query_time}ms"
		elif [[ "$query_time" -lt 500 ]]; then
			echo -e "${YELLOW}⚠ Query time: ${query_time}ms (Acceptable)${NC}"
			log_message "Response time WARNING: ${query_time}ms"
		else
			echo -e "${RED}✗ Query time: ${query_time}ms (Slow!)${NC}"
			log_message "Response time CRITICAL: ${query_time}ms"
		fi
	else
		echo -e "${RED}✗ Could not measure query time${NC}"
		log_message "Response time check: FAILED"
	fi
}

# ==========================================
# Function: Check zone file syntax
# ==========================================
check_zone_syntax() {
	log_message "Checking zone file syntax..."

	# Check forward zone
	if named-checkzone "$DOMAIN" /var/named/"$DOMAIN".zone &>/dev/null; then
		echo -e "${GREEN}✓ Forward zone syntax: OK${NC}"
		log_message "Forward zone syntax: OK"
	else
		echo -e "${RED}✗ Forward zone syntax: ERRORS FOUND${NC}"
		log_message "Forward zone syntax: FAILED"
		named-checkzone "$DOMAIN" /var/named/"$DOMAIN".zone 2>&1 | tee -a "$LOG_FILE"
	fi

	# Check reverse zone
	if named-checkzone 56.168.192.in-addr.arpa /var/named/192.168.56.rev &>/dev/null; then
		echo -e "${GREEN}✓ Reverse zone syntax: OK${NC}"
		log_message "Reverse zone syntax: OK"
	else
		echo -e "${RED}✗ Reverse zone syntax: ERRORS FOUND${NC}"
		log_message "Reverse zone syntax: FAILED"
	fi
}

# ==========================================
# Main Execution
# ==========================================
main() {
	echo "=============================================="
	echo "  TechCorp DNS Health Check"
	echo "  $(date '+%Y-%m-%d %H:%M:%S')"
	echo "=============================================="
	echo ""

	log_message "=== DNS Health Check Started ==="

	# Track overall status
	overall_status=0

	# Check 1: DNS Service
	check_dns_service || overall_status=1
	echo ""

	# Check 2: DNS Port
	check_dns_port || overall_status=1
	echo ""

	# Check 3: Zone File Syntax
	check_zone_syntax
	echo ""

	# Check 4: DNS Resolution Tests
	echo "Testing DNS Resolution:"
	echo "----------------------------------------------"
	for host in "${TEST_HOSTS[@]}"; do
		test_dns_resolution "$host" || overall_status=1
	done
	echo ""

	# Check 5: Reverse DNS Tests
	echo "Testing Reverse DNS:"
	echo "----------------------------------------------"
	test_reverse_dns "192.168.56.10"
	test_reverse_dns "192.168.56.40"
	echo ""

	# Check 6: Response Time
	echo "Checking DNS Response Time:"
	echo "----------------------------------------------"
	check_response_time "prod-web.techcorp.local"
	echo ""

	# Final Summary
	echo "=============================================="
	if [[ $overall_status -eq 0 ]]; then
		echo -e "${GREEN}✓ DNS Health Check: ALL TESTS PASSED${NC}"
		log_message "=== DNS Health Check Completed: SUCCESS ==="
	else
		echo -e "${RED}✗ DNS Health Check: SOME TESTS FAILED${NC}"
		log_message "=== DNS Health Check Completed: FAILURES DETECTED ==="
	fi
	echo "=============================================="

	exit $overall_status
}

# Run main function
main