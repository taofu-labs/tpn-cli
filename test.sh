#!/bin/sh


# --------------------
# Helpers
# --------------------

green() {
  if [ $# -gt 0 ]; then
    printf '\033[0;32m%s\033[0m\n' "$*"
  else
    while IFS= read -r line; do
      printf '\033[0;32m%s\033[0m\n' "$line"
    done
  fi
}

red() {
  if [ $# -gt 0 ]; then
    printf '\033[0;31m%s\033[0m\n' "$*"
  else
    while IFS= read -r line; do
      printf '\033[0;31m%s\033[0m\n' "$line"
    done
  fi
}

# Path to tpn.sh (adjust if needed)
TPN="DEBUG=true RETRY=1 TIMEOUT=30 sh ./tpn.sh"

# Parse --fail-fast argument
FAIL_FAST=0
for arg in "$@"; do
  if [ "$arg" = "--fail-fast" ]; then
    FAIL_FAST=1
  fi
done

fail=0

# Set up trap to handle Ctrl+C
trap 'printf "\nTest suite interrupted by user. Cleaning up...\n"; cleanup; exit 130' INT

# Arrays to track test results
PASSED_TESTS=""
FAILED_TESTS=""
WORKING_COUNTRIES=""
BROKEN_COUNTRIES=""

print_green() { green "$1"; }
print_red() { red "$1"; }

# Function to add test results
add_test_result() {
  test_name="$1"
  result="$2"  # "pass" or "fail"
  
  if [ "$result" = "pass" ]; then
    if [ -z "$PASSED_TESTS" ]; then
      PASSED_TESTS="$test_name"
    else
      PASSED_TESTS="$PASSED_TESTS, $test_name"
    fi
  else
    if [ -z "$FAILED_TESTS" ]; then
      FAILED_TESTS="$test_name"
    else
      FAILED_TESTS="$FAILED_TESTS, $test_name"
    fi
  fi
}

# Function to add country results
add_country_result() {
  country="$1"
  result="$2"  # "working" or "broken"
  
  if [ "$result" = "working" ]; then
    if [ -z "$WORKING_COUNTRIES" ]; then
      WORKING_COUNTRIES="$country"
    else
      WORKING_COUNTRIES="$WORKING_COUNTRIES, $country"
    fi
  else
    if [ -z "$BROKEN_COUNTRIES" ]; then
      BROKEN_COUNTRIES="$country"
    else
      BROKEN_COUNTRIES="$BROKEN_COUNTRIES, $country"
    fi
  fi
}

cleanup() {
  printf "Clean up test output files? [Y/n] "
  read ans || ans="Y"
  case "$ans" in 
    [Nn]*) printf "Keeping test output files.\n";;
    *) rm -f countries.out countries_code.out status.out connect_missing.out disconnect.out connect_any.out disconnect_any.out help.out connect_*.out call.log calls.out
       printf "Test output files cleaned up.\n";;
  esac
}

run_and_log() {
  printf '\n%s\n' "$*"
  eval "$*"
}

fail_exit() {
  if [ $FAIL_FAST -eq 1 ]; then
    print_red "Fail-fast enabled. Exiting on first failure."
    # Clean up .out files before exit
    cleanup
    exit 1
  fi
}

# Clean up any existing .out files before starting
cleanup

# Start message
printf 'Starting TPN CLI test suite...\n'
printf 'Note that you can track the api calls in the calls.out file.\n'
printf '===============================\n'

# Test that countries command returns a list with minimum length
printf '\nTesting: countries (default)\n'
run_and_log "$TPN countries | tee countries.out"
if [ $(wc -c < countries.out) -ge 10 ]; then
  print_green "PASS: countries"
  add_test_result "countries" "pass"
else
  print_red "FAIL: countries (output too short)"
  add_test_result "countries" "fail"
  fail=1
  fail_exit
fi

# Test that countries code command returns country codes with minimum length
printf '\nTesting: countries code\n'
run_and_log "$TPN countries code | tee countries_code.out"
if [ $(wc -c < countries_code.out) -ge 10 ]; then
  print_green "PASS: countries code"
  add_test_result "countries code" "pass"
else
  print_red "FAIL: countries code (output too short)"
  add_test_result "countries code" "fail"
  fail=1
  fail_exit
fi

# Test that status command shows connection status and IP address
printf '\nTesting: status\n'
run_and_log "$TPN status | tee status.out"
if grep -q "TPN status:" status.out; then
  print_green "PASS: status"
  add_test_result "status" "pass"
else
  print_red "FAIL: status"
  add_test_result "status" "fail"
  fail=1
  fail_exit
fi

# Test that help command displays usage information
printf '\nTesting: help\n'
run_and_log "$TPN help > help.out 2>&1"
if grep -qi "usage" help.out; then
  print_green "PASS: help"
  add_test_result "help" "pass"
else
  print_red "FAIL: help"
  add_test_result "help" "fail"
  fail=1
  fail_exit
fi

if [ $fail -eq 0 ]; then
  print_green "All tests passed."
else
  print_red "Some tests failed."
fi

# Test dry run connection to each available country code
printf '\nTesting: dry run connect for each country\n'
# Extract country codes from the JSON array format (e.g., ["us","uk","ca"])
# Use countries_code.out which contains actual country codes, not full names
countries=$(sed 's/\[//g; s/\]//g; s/"//g' countries_code.out | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
for country in $countries; do
  # Skip empty lines
  [ -z "$country" ] && continue

  # Skip invalid country codes (non-alphabetic)
  if ! echo "$country" | grep -qE '^[a-zA-Z]{2,}$'; then
    print_red "Skipping invalid country code: $country"
    continue
  fi

  printf '\nTesting: dry run connect to %s\n' "$country"
  run_and_log "$TPN connect -f \"$country\" --dry | tee connect_${country}.out"
  if grep -qi "DRY RUN" "connect_${country}.out" && ! grep -qi "error" "connect_${country}.out"; then
    print_green "PASS: dry run connect to $country"
    add_country_result "$country" "working"
  else
    print_red "FAIL: dry run connect to $country"
    add_country_result "$country" "broken"
    fail=1
    fail_exit
  fi
done

# Test actual VPN connection to any available server
printf '\nTesting: connect to 'any' (real connection)\n'
run_and_log "$TPN connect -f any | tee connect_any.out"
if grep -qi "IP address changed" connect_any.out && ! grep -qi "error" connect_any.out; then
  print_green "PASS: connect any (real connection)"
  add_test_result "connect any" "pass"
  sleep 10
else
  print_red "FAIL: connect any (real connection)"
  add_test_result "connect any" "fail"
  fail=1
  fail_exit
fi

# Test disconnecting from the VPN and restoring original IP
printf '\nTesting: disconnect after connect (real disconnect)\n'
run_and_log "$TPN disconnect | tee disconnect_any.out"
if grep -qi "IP changed back" disconnect_any.out && ! grep -qi "error" disconnect_any.out; then
  print_green "PASS: disconnect after connect (real disconnect)"
  add_test_result "disconnect after connect" "pass"
else
  print_red "FAIL: disconnect after connect (real disconnect)"
  add_test_result "disconnect after connect" "fail"
  fail=1
  fail_exit
fi


# Print summary
printf '\n=== TEST SUMMARY ===\n'
if [ -n "$PASSED_TESTS" ]; then
  green "Tests passed: $PASSED_TESTS"
else
  green "Tests passed: none"
fi

if [ -n "$FAILED_TESTS" ]; then
  red "Tests failed: $FAILED_TESTS"
else
  green "Tests failed: none"
fi

if [ -n "$WORKING_COUNTRIES" ]; then
  green "Countries with working miners: $WORKING_COUNTRIES"
else
  red "Countries with working miners: none"
fi

if [ -n "$BROKEN_COUNTRIES" ]; then
  red "Countries without working miners: $BROKEN_COUNTRIES"
else
  green "Countries without working miners: none"
fi

# Clean up .out files
cleanup

exit $fail
