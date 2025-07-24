import Foundation

// Test different logging methods
print("TEST 1: Basic print statement")
NSLog("TEST 2: NSLog statement")
debugPrint("TEST 3: debugPrint statement")

// Test with different output streams
fputs("TEST 4: fputs to stdout\n", stdout)
fflush(stdout)

// Test with error output
fputs("TEST 5: fputs to stderr\n", stderr)
fflush(stderr)

// Test with os_log (if available)
if #available(iOS 14.0, *) {
    import os
    let logger = Logger(subsystem: "com.gym.api", category: "test")
    logger.info("TEST 6: os.Logger info message")
}

print("All tests completed")