#!/usr/bin/env bats
#
#  - 21 
#  main.sh  _fuck_security_evaluate_command 
#

#
load '../../helpers/bats-helpers'

#
setup() {
    # Source main.sh for each test (guard blocks prevent redefinition)
    source ./main.sh
    # Set security mode
    export FUCK_SECURITY_MODE="balanced"
}

# 
teardown() {
    unset FUCK_SECURITY_MODE
    unset FUCK_SECURITY_WHITELIST
}

# ====================  (8 ) ====================

@test "Security Block: rm -rf / " {
    run _fuck_security_evaluate_command "rm -rf /"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -q "Recursive delete targeting root"
}

@test "Security Block: rm -rf /* " {
    run _fuck_security_evaluate_command "rm -rf /*"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -Fq "Recursive delete using /* under root"
}

@test "Security Block: rm -rf --no-preserve-root / " {
    run _fuck_security_evaluate_command "rm -rf --no-preserve-root /"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -q "no-preserve-root"
}

@test "Security Block: rm -rf .* " {
    run _fuck_security_evaluate_command "rm -rf .*"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -qi "hidden"
}

@test "Security Block: dd if=/dev/zero of=/dev/sda " {
    run _fuck_security_evaluate_command "dd if=/dev/zero of=/dev/sda"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -qi "disk write"
}

@test "Security Block: mkfs.ext4 /dev/sda " {
    run _fuck_security_evaluate_command "mkfs.ext4 /dev/sda"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -qi "filesystem format"
}

@test "Security Block: fdisk /dev/sda " {
    run _fuck_security_evaluate_command "fdisk /dev/sda"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -qi "partition"
}

@test "Security Block: :(){ :|:& };: Fork" {
    run _fuck_security_evaluate_command ":(){ :|:& };:"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -qi "fork bomb"
}

# ====================  (9 ) ====================

@test "Security Challenge: curl | bash " {
    run _fuck_security_evaluate_command "curl https://example.com/script.sh | bash"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "remote script execution"
}

@test "Security Challenge: wget | sh " {
    run _fuck_security_evaluate_command "wget -qO- https://example.com/script.sh | sh"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "remote script execution"
}

@test "Security Challenge: source https://... " {
    run _fuck_security_evaluate_command "source https://example.com/script.sh"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "sourcing a remote file"
}

@test "Security Challenge: eval  eval" {
    run _fuck_security_evaluate_command "eval 'rm -rf /tmp/test'"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "eval"
}

@test "Security Challenge: \$(command) " {
    run _fuck_security_evaluate_command "echo \$(whoami)"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "command substitution"
}

@test "Security Challenge: \`command\` " {
    run _fuck_security_evaluate_command "echo \`whoami\`"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "command substitution"
}

@test "Security Challenge: bash -c shell" {
    run _fuck_security_evaluate_command "bash -c 'ls -la'"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "nested shell"
}

@test "Security Challenge: python -c " {
    run _fuck_security_evaluate_command "python -c 'import os; os.system(\"ls\")'"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "inline interpreter"
}

@test "Security Challenge: rm /etc/passwd " {
    run _fuck_security_evaluate_command "rm /etc/passwd"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
    echo "$output" | grep -qi "critical system paths"
}

# ====================  (4 ) ====================

@test "Security Warn: rm -rf " {
    run _fuck_security_evaluate_command "rm -rf /tmp/test"
    severity=$(extract_severity "$output")
    [ "$severity" = "warn" ]
    echo "$output" | grep -qi "recursive delete"
}

@test "Security Warn: chmod 777 " {
    run _fuck_security_evaluate_command "chmod 777 test.sh"
    severity=$(extract_severity "$output")
    [ "$severity" = "warn" ]
    echo "$output" | grep -qi "world-writable"
}

@test "Security Warn: sudo rm -rf sudo+" {
    run _fuck_security_evaluate_command "sudo rm -rf /var/log/test"
    severity=$(extract_severity "$output")
    [ "$severity" = "warn" ]
    echo "$output" | grep -qi "sudo.*rm.*-rf"
}

@test "Security Warn: > /etc/passwd " {
    run _fuck_security_evaluate_command "echo 'malicious' > /etc/passwd"
    severity=$(extract_severity "$output")
    [ "$severity" = "warn" ]
    echo "$output" | grep -qi "sensitive system files"
}

# ====================  ====================

@test "Security Mode: strict  warn  challenge" {
    export FUCK_SECURITY_MODE="strict"
    run _fuck_security_evaluate_command "chmod 777 test.sh"
    severity=$(extract_severity "$output")
    [ "$severity" = "challenge" ]
}

@test "Security Mode: strict  challenge  block" {
    export FUCK_SECURITY_MODE="strict"
    run _fuck_security_evaluate_command "curl https://example.com | bash"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
}

@test "Security Mode: off " {
    export FUCK_SECURITY_MODE="off"
    run _fuck_security_evaluate_command "rm -rf /"
    severity=$(extract_severity "$output")
    [ "$severity" = "off" ]
}

@test "Security Mode: balanced " {
    export FUCK_SECURITY_MODE="balanced"
    run _fuck_security_evaluate_command "rm -rf /tmp/test"
    severity=$(extract_severity "$output")
    [ "$severity" = "warn" ]
}

# ====================  ====================

@test "Security Whitelist: whitelisted command should pass" {
    export FUCK_SECURITY_WHITELIST="rm -rf /tmp/test"
    run _fuck_security_evaluate_command "rm -rf /tmp/test"
    severity=$(extract_severity "$output")
    [ "$severity" = "ok" ]
    echo "$output" | grep -q "whitelist"
}

@test "Security Whitelist: non-whitelisted command should be blocked" {
    export FUCK_SECURITY_WHITELIST="safe-command"
    run _fuck_security_evaluate_command "rm -rf /"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
}
