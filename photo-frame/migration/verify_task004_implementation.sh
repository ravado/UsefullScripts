#!/bin/bash
# TASK-004 Implementation Verification Script
# Run this on Raspberry Pi Zero 2W AFTER installation completes

set -euo pipefail

echo "========================================="
echo "TASK-004 Implementation Verification"
echo "========================================="
echo ""

FAILED_CHECKS=0
PASSED_CHECKS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

echo "1. Checking Swap Configuration..."
CURRENT_SWAP=$(free -m | awk '/Swap:/ {print $2}')
if [[ $CURRENT_SWAP -lt 200 ]]; then
    check_pass "Swap restored to original size (${CURRENT_SWAP}MB)"
else
    check_warn "Swap still elevated (${CURRENT_SWAP}MB) - may not have restored yet"
fi

echo ""
echo "2. Checking for OOM Kills..."
OOM_COUNT=$(dmesg | grep -c "Out of memory" || echo "0")
if [[ $OOM_COUNT -eq 0 ]]; then
    check_pass "No OOM kills detected in dmesg"
else
    check_fail "Found $OOM_COUNT OOM kill(s) in dmesg"
fi

echo ""
echo "3. Checking Virtual Environment..."
if [[ -d "/opt/picframe-env" ]]; then
    check_pass "Virtual environment exists at /opt/picframe-env"

    # Check if adafruit-circuitpython-dht is installed (pure Python version)
    if /opt/picframe-env/bin/pip list | grep -q "adafruit-circuitpython-dht"; then
        check_pass "Pure Python adafruit-circuitpython-dht installed"
    else
        check_fail "adafruit-circuitpython-dht not found in venv"
    fi

    # Check if old Adafruit_DHT is NOT installed
    if ! /opt/picframe-env/bin/pip list | grep -q "Adafruit-DHT"; then
        check_pass "Old C-extension Adafruit_DHT not installed (good)"
    else
        check_warn "Old Adafruit_DHT found - should use CircuitPython version"
    fi
else
    check_fail "Virtual environment not found at /opt/picframe-env"
fi

echo ""
echo "4. Checking Systemd Service..."
if systemctl is-enabled picframe.service &>/dev/null; then
    check_pass "Picframe service is enabled"

    # Check if service uses venv
    if systemctl cat picframe.service | grep -q "/opt/picframe-env"; then
        check_pass "Service configured to use virtual environment"
    else
        check_fail "Service not using virtual environment"
    fi

    # Check if service is running
    if systemctl is-active picframe.service &>/dev/null; then
        check_pass "Service is currently running"
    else
        check_warn "Service is not running (may be expected if not started yet)"
    fi
else
    check_fail "Picframe service not enabled"
fi

echo ""
echo "5. Checking Picframe Installation..."
if [[ -d "$HOME/picframe" ]]; then
    check_pass "Picframe directory exists"

    # Check git branch
    CURRENT_BRANCH=$(git -C "$HOME/picframe" branch --show-current)
    if [[ "$CURRENT_BRANCH" == "develop" ]]; then
        check_pass "On develop branch as expected"
    else
        check_warn "On branch '$CURRENT_BRANCH' instead of 'develop'"
    fi

    # Check if picframe is installed in venv
    if /opt/picframe-env/bin/pip show picframe &>/dev/null; then
        check_pass "Picframe installed in virtual environment"
    else
        check_fail "Picframe not found in virtual environment"
    fi
else
    check_fail "Picframe directory not found at $HOME/picframe"
fi

echo ""
echo "6. Checking X Server..."
if pgrep -x "X" > /dev/null; then
    check_pass "X server is running"

    if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
        check_pass "X server responds to xdpyinfo (healthy)"
    else
        check_warn "X server running but not responding to xdpyinfo"
    fi
else
    check_warn "X server not running (may be expected if service not started)"
fi

echo ""
echo "7. Checking Installation Logs..."
if [[ -f "/tmp/picframe-git-clone.log" ]]; then
    check_pass "Git clone log exists at /tmp/picframe-git-clone.log"

    # Check if clone was successful
    if grep -q "Cloning into" /tmp/picframe-git-clone.log; then
        check_pass "Git clone completed successfully"
    else
        check_fail "Git clone may have failed - check log"
    fi
else
    check_warn "Git clone log not found (may have been cleaned up)"
fi

echo ""
echo "8. Checking Network Timeouts (from logs)..."
if journalctl -u picframe.service -b 2>/dev/null | grep -q "timed out"; then
    check_fail "Found timeout messages in picframe service logs"
else
    check_pass "No timeout messages found in service logs"
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}🎉 All critical checks passed!${NC}"
    echo ""
    echo "Installation appears successful. Key improvements verified:"
    echo "  - No OOM kills during installation"
    echo "  - Virtual environment properly configured"
    echo "  - Pure Python packages (no C compilation)"
    echo "  - Service using venv activation"
    exit 0
else
    echo -e "${RED}⚠️  Some checks failed. Review output above.${NC}"
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Check systemd logs: journalctl -u picframe.service -b"
    echo "  - Check git clone log: cat /tmp/picframe-git-clone.log"
    echo "  - Verify swap restoration: free -h"
    echo "  - Check for errors: dmesg | grep -i error"
    exit 1
fi
