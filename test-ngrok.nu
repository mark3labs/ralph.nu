#!/usr/bin/env nu

# Test script for ngrok integration
# Verifies: CLI flags, code structure, password validation logic

print "Testing ngrok integration..."

# Test 1: CLI flags exist
print "\nTest 1: CLI flags exist in help"
let help = (./ralph.nu --help | complete)
if ($help.stdout | str contains "--ngrok") and ($help.stdout | str contains "--ngrok-domain") {
  print "  ✓ PASSED: CLI flags present"
} else {
  print "  ✗ FAILED: CLI flags missing from help"
  exit 1
}

# Test 2: start-ngrok function exists
print "\nTest 2: start-ngrok function exists"
let code = (open ralph.nu)
if ($code | str contains "def start-ngrok") {
  print "  ✓ PASSED: start-ngrok function defined"
} else {
  print "  ✗ FAILED: start-ngrok function missing"
  exit 1
}

# Test 3: Password validation code exists
print "\nTest 3: Password validation code exists"
if ($code | str contains "8-128 characters") and ($code | str contains "pw_len") {
  print "  ✓ PASSED: Password validation implemented"
} else {
  print "  ✗ FAILED: Password validation missing"
  exit 1
}

# Test 4: Basic auth formatting exists
print "\nTest 4: Basic auth formatting exists"
if ($code | str contains '--basic-auth $auth') and ($code | str contains 'ralph:($password)') {
  print "  ✓ PASSED: Basic auth formatting correct"
} else {
  print "  ✗ FAILED: Basic auth formatting incorrect"
  exit 1
}

# Test 5: Domain support exists
print "\nTest 5: Domain support exists"
if ($code | str contains '--domain $domain') {
  print "  ✓ PASSED: Domain support implemented"
} else {
  print "  ✗ FAILED: Domain support missing"
  exit 1
}

# Test 6: ngrok API polling exists
print "\nTest 6: ngrok API polling exists"
if ($code | str contains 'localhost:4040/api/tunnels') {
  print "  ✓ PASSED: API polling implemented"
} else {
  print "  ✗ FAILED: API polling missing"
  exit 1
}

# Test 7: Cleanup includes ngrok
print "\nTest 7: Cleanup includes ngrok"
if ($code | str contains "ngrok http") and ($code | str contains "pkill -f") {
  print "  ✓ PASSED: Cleanup code includes ngrok"
} else {
  print "  ✗ FAILED: Cleanup missing ngrok handling"
  exit 1
}

# Test 8: Integration in main flow
print "\nTest 8: Integration in main flow"
if ($code | str contains 'start-ngrok $port $ngrok') {
  print "  ✓ PASSED: ngrok integrated into main flow"
} else {
  print "  ✗ FAILED: ngrok not integrated into main flow"
  exit 1
}

print "\n✓ All static code tests passed!"
print "\nNote: For full integration test, run:"
print "  ./ralph.nu --name test --ngrok \"testpass123\" --iterations 1"
