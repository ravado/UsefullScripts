#!/bin/bash
set -euo pipefail

# TASK-004 Phase 3 Verification Script
# Verifies that screen control scripts are properly installed and functional

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "TASK-004 Phase 3 Verification"
echo "Screen Control Implementation"
echo "========================================="
echo ""

ERRORS=0

check_file() {
    local file=$1
    local should_be_executable=$2

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} Found: $file"
        if [[ "$should_be_executable" == "yes" ]]; then
            if [[ -x "$file" ]]; then
                echo -e "${GREEN}  ✓${NC} Executable"
            else
                echo -e "${RED}  ✗${NC} Not executable"
                ((ERRORS++))
            fi
        fi
    else
        echo -e "${RED}✗${NC} Missing: $file"
        ((ERRORS++))
    fi
}

# Check repository structure
echo "1. Checking repository structure..."
echo ""

REPO_DIR="/Users/ivan.cherednychok/Projects/usefull-scripts"
SCRIPTS_DIR="$REPO_DIR/photo-frame/scripts"

check_file "$SCRIPTS_DIR/screen_control.sh" "yes"
check_file "$SCRIPTS_DIR/install_crontab.sh" "yes"
check_file "$SCRIPTS_DIR/install_timers.sh" "yes"
check_file "$SCRIPTS_DIR/test_screen_control.sh" "yes"
check_file "$SCRIPTS_DIR/README.md" "no"

echo ""

# Check git status
echo "2. Checking git commit status..."
echo ""

cd "$REPO_DIR"
if git log -1 --oneline | grep -q "screen control"; then
    echo -e "${GREEN}✓${NC} Screen control scripts committed to git"
    git log -1 --oneline
else
    echo -e "${YELLOW}⚠${NC} Latest commit doesn't mention screen control"
    git log -1 --oneline
fi

echo ""

# Check script syntax
echo "3. Checking script syntax..."
echo ""

for script in "$SCRIPTS_DIR"/*.sh; do
    if bash -n "$script" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Syntax OK: $(basename "$script")"
    else
        echo -e "${RED}✗${NC} Syntax error: $(basename "$script")"
        ((ERRORS++))
    fi
done

echo ""

# Verify script content
echo "4. Verifying script content..."
echo ""

# Check screen_control.sh has key functions
if grep -q "screen_off()" "$SCRIPTS_DIR/screen_control.sh" && \
   grep -q "screen_on()" "$SCRIPTS_DIR/screen_control.sh" && \
   grep -q "get_status()" "$SCRIPTS_DIR/screen_control.sh"; then
    echo -e "${GREEN}✓${NC} screen_control.sh has required functions"
else
    echo -e "${RED}✗${NC} screen_control.sh missing required functions"
    ((ERRORS++))
fi

# Check install_crontab.sh has cron entries
if grep -q "0 23 \* \* \*" "$SCRIPTS_DIR/install_crontab.sh" && \
   grep -q "0 7 \* \* \*" "$SCRIPTS_DIR/install_crontab.sh"; then
    echo -e "${GREEN}✓${NC} install_crontab.sh has correct schedule (23:00 off, 07:00 on)"
else
    echo -e "${RED}✗${NC} install_crontab.sh has incorrect schedule"
    ((ERRORS++))
fi

# Check install_timers.sh creates systemd files
if grep -q "picframe-screen-off.service" "$SCRIPTS_DIR/install_timers.sh" && \
   grep -q "picframe-screen-on.service" "$SCRIPTS_DIR/install_timers.sh" && \
   grep -q "OnCalendar=23:00" "$SCRIPTS_DIR/install_timers.sh" && \
   grep -q "OnCalendar=07:00" "$SCRIPTS_DIR/install_timers.sh"; then
    echo -e "${GREEN}✓${NC} install_timers.sh creates systemd timers with correct schedule"
else
    echo -e "${RED}✗${NC} install_timers.sh missing systemd timer configuration"
    ((ERRORS++))
fi

# Check test script has all test cases
if grep -q "Testing screen OFF" "$SCRIPTS_DIR/test_screen_control.sh" && \
   grep -q "Testing screen ON" "$SCRIPTS_DIR/test_screen_control.sh" && \
   grep -q "Rapid toggle" "$SCRIPTS_DIR/test_screen_control.sh"; then
    echo -e "${GREEN}✓${NC} test_screen_control.sh has all test cases"
else
    echo -e "${RED}✗${NC} test_screen_control.sh missing test cases"
    ((ERRORS++))
fi

echo ""

# Check README content
echo "5. Checking documentation..."
echo ""

if grep -q "screen_control.sh" "$SCRIPTS_DIR/README.md" && \
   grep -q "install_crontab.sh" "$SCRIPTS_DIR/README.md" && \
   grep -q "install_timers.sh" "$SCRIPTS_DIR/README.md" && \
   grep -q "Troubleshooting" "$SCRIPTS_DIR/README.md"; then
    echo -e "${GREEN}✓${NC} README.md is comprehensive"
else
    echo -e "${YELLOW}⚠${NC} README.md may be incomplete"
fi

echo ""

# Summary
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Push to remote: git push"
    echo "2. On Raspberry Pi, pull latest changes"
    echo "3. Copy scripts to ~/picframe/scripts/"
    echo "4. Run test: ~/picframe/scripts/test_screen_control.sh"
    echo "5. Install scheduling: ~/picframe/scripts/install_timers.sh"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the errors above before deploying."
    exit 1
fi
