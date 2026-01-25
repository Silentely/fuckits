#!/bin/bash
#
# End-to-end tests for deployed Worker
# These tests verify the production deployment is working correctly
#
# Usage:
#   ./tests/e2e/real-deployment.test.sh [WORKER_URL]
#
# Example:
#   ./tests/e2e/real-deployment.test.sh https://fuckits.25500552.xyz

set -euo pipefail

# Colors
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
C_RESET='\033[0m'

# Configuration
WORKER_URL="${1:-https://fuckits.25500552.xyz}"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test helpers
test_start() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -ne "${C_CYAN}[TEST $TOTAL_TESTS]${C_RESET} $1... "
}

test_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "${C_GREEN}✓ PASS${C_RESET}"
    if [ -n "${1:-}" ]; then
        echo "         $1"
    fi
}

test_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "${C_RED}✗ FAIL${C_RESET}"
    if [ -n "${1:-}" ]; then
        echo "         Error: $1"
    fi
}

test_skip() {
    echo -e "${C_YELLOW}⊘ SKIP${C_RESET}"
    if [ -n "${1:-}" ]; then
        echo "         $1"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS - 1))
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    command -v curl &> /dev/null || missing+=("curl")
    command -v jq &> /dev/null || missing+=("jq")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${C_RED}Error: Missing required tools: ${missing[*]}${C_RESET}"
        echo "Install them and try again."
        exit 1
    fi
}

# Test 1: Health check
test_health_check() {
    test_start "Health check endpoint"
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$WORKER_URL/health")
    local body=$(echo "$response" | head -n -1)
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "200" ]; then
        test_fail "Expected 200, got $code"
        return
    fi
    
    local status=$(echo "$body" | jq -r '.status' 2>/dev/null)
    if [ "$status" != "ok" ]; then
        test_fail "Expected status 'ok', got '$status'"
        return
    fi
    
    local has_key=$(echo "$body" | jq -r '.hasApiKey' 2>/dev/null)
    test_pass "Status: $status, API Key: $has_key"
}

# Test 2: GET request returns installer
test_get_installer() {
    test_start "GET / returns installer script"
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$WORKER_URL" \
        -H "User-Agent: curl/7.68.0")
    local body=$(echo "$response" | head -n -1)
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "200" ]; then
        test_fail "Expected 200, got $code"
        return
    fi
    
    if ! echo "$body" | grep -q "#!/bin/bash"; then
        test_fail "Response doesn't look like a bash script"
        return
    fi
    
    if ! echo "$body" | grep -q "fuckits"; then
        test_fail "Script doesn't contain 'fuckits'"
        return
    fi
    
    test_pass "Installer script returned ($(echo "$body" | wc -l) lines)"
}

# Test 3: Browser request redirects
test_browser_redirect() {
    test_start "Browser request redirects to GitHub"
    
    local response
    response=$(curl -s -w "\n%{http_code}" -L "$WORKER_URL" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124")
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "200" ]; then
        test_fail "Expected 200 (after redirect), got $code"
        return
    fi
    
    test_pass "Redirected successfully"
}

# Test 4: Chinese locale
test_chinese_locale() {
    test_start "Chinese locale (/zh) returns Chinese script"
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$WORKER_URL/zh" \
        -H "User-Agent: curl/7.68.0")
    local body=$(echo "$response" | head -n -1)
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "200" ]; then
        test_fail "Expected 200, got $code"
        return
    fi
    
    # Check for Chinese characters
    if ! echo "$body" | grep -q "安装脚本"; then
        test_fail "Response doesn't contain Chinese text"
        return
    fi
    
    test_pass "Chinese script returned"
}

# Test 5: POST request generates command
test_post_command() {
    test_start "POST / generates shell command"
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$WORKER_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "sysinfo": "OS=Debian; PkgMgr=apt",
            "prompt": "list files"
        }')
    local body=$(echo "$response" | head -n -1)
    local code=$(echo "$response" | tail -n 1)
    
    # Accept both 200 (success) and 429 (quota exceeded)
    if [ "$code" = "429" ]; then
        test_skip "Quota exceeded (expected in production)"
        return
    fi
    
    if [ "$code" != "200" ]; then
        test_fail "Expected 200, got $code"
        return
    fi
    
    if [ -z "$body" ]; then
        test_fail "Response is empty"
        return
    fi
    
    # Check if response looks like a command
    if echo "$body" | grep -Eq "^\{.*error.*\}$"; then
        test_fail "Received error: $body"
        return
    fi
    
    test_pass "Command: $body"
}

# Test 6: POST without sysinfo fails
test_post_missing_sysinfo() {
    test_start "POST without sysinfo returns 400"
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$WORKER_URL" \
        -H "Content-Type: application/json" \
        -d '{"prompt": "test"}')
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "400" ]; then
        test_fail "Expected 400, got $code"
        return
    fi
    
    test_pass "Correctly rejected invalid request"
}

# Test 7: POST without prompt fails
test_post_missing_prompt() {
    test_start "POST without prompt returns 400"
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$WORKER_URL" \
        -H "Content-Type: application/json" \
        -d '{"sysinfo": "OS=Linux"}')
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "400" ]; then
        test_fail "Expected 400, got $code"
        return
    fi
    
    test_pass "Correctly rejected invalid request"
}

# Test 8: CORS headers present
test_cors_headers() {
    test_start "CORS headers are set"
    
    local headers
    headers=$(curl -s -I "$WORKER_URL/health")
    
    if ! echo "$headers" | grep -qi "Access-Control-Allow-Origin"; then
        test_fail "CORS header not found"
        return
    fi
    
    test_pass "CORS enabled"
}

# Test 9: OPTIONS request
test_options_request() {
    test_start "OPTIONS request returns CORS headers"
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X OPTIONS "$WORKER_URL" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type")
    local code=$(echo "$response" | tail -n 1)
    
    if [ "$code" != "204" ]; then
        test_fail "Expected 204, got $code"
        return
    fi
    
    test_pass "CORS preflight handled"
}

# Test 10: Performance test
test_performance() {
    test_start "Response time is acceptable"
    
    local start=$(date +%s%N)
    curl -s "$WORKER_URL/health" > /dev/null
    local end=$(date +%s%N)
    
    local duration_ms=$(( (end - start) / 1000000 ))
    
    if [ $duration_ms -gt 3000 ]; then
        test_fail "Response took ${duration_ms}ms (> 3000ms)"
        return
    fi
    
    test_pass "Response time: ${duration_ms}ms"
}

# Main execution
main() {
    echo -e "${C_CYAN}========================================${C_RESET}"
    echo -e "${C_CYAN}fuckits E2E Deployment Tests${C_RESET}"
    echo -e "${C_CYAN}========================================${C_RESET}"
    echo -e "Worker URL: ${C_YELLOW}$WORKER_URL${C_RESET}"
    echo ""
    
    check_dependencies
    
    # Run all tests
    test_health_check
    test_get_installer
    test_browser_redirect
    test_chinese_locale
    test_post_command
    test_post_missing_sysinfo
    test_post_missing_prompt
    test_cors_headers
    test_options_request
    test_performance
    
    # Summary
    echo ""
    echo -e "${C_CYAN}========================================${C_RESET}"
    echo -e "${C_CYAN}Test Summary${C_RESET}"
    echo -e "${C_CYAN}========================================${C_RESET}"
    echo -e "Total:  $TOTAL_TESTS"
    echo -e "Passed: ${C_GREEN}$PASSED_TESTS${C_RESET}"
    echo -e "Failed: ${C_RED}$FAILED_TESTS${C_RESET}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${C_GREEN}✓ All tests passed!${C_RESET}"
        exit 0
    else
        echo -e "${C_RED}✗ Some tests failed${C_RESET}"
        exit 1
    fi
}

main "$@"
