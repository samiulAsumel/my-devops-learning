#!/bin/bash
#==============================================================================
# DNS Monitoring Script - Checks Both Primary and Secondary
#==============================================================================

PRIMARY_DNS="192.168.56.5"
SECONDARY_DNS="192.168.56.6"
TEST_HOSTNAME="prod-web.techcorp.local"
ALERT_EMAIL="admin@techcorp.local"

check_dns_server() {
    local dns_server=$1
    local server_name=$2
    
    echo "Checking $server_name ($dns_server)..."
    
    # Test resolution
    result=$(dig @"$dns_server" $TEST_HOSTNAME +short 2>/dev/null)
    
    if [[ -n "$result" ]]; then
        echo "✓ $server_name is responding: $result"
        
        # Check response time
        query_time=$(dig @"$dns_server" $TEST_HOSTNAME | grep "Query time:" | awk '{print $4}')
        echo "  Response time: ${query_time}ms"
        
        if [[ $query_time -gt 500 ]]; then
            echo "⚠ WARNING: Slow response time!"
        fi
        
        return 0
    else
        echo "✗ $server_name is NOT responding!"
        
        # Send alert
        echo "$server_name DNS failure at $(date)" | \
          mail -s "DNS ALERT: $server_name Down" $ALERT_EMAIL
        
        return 1
    fi
}

main() {
    echo "=========================================="
    echo "DNS Monitoring Check - $(date)"
    echo "=========================================="
    
    check_dns_server $PRIMARY_DNS "Primary DNS"
    echo ""
    check_dns_server $SECONDARY_DNS "Secondary DNS"
    echo ""
    
    echo "=========================================="
    echo "Monitoring check complete"
    echo "=========================================="
}

main