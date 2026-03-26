# Session Replay Performance Test Results

**Test Date:** March 26, 2026
**Platform:** iOS - Real Device (LambdaTest)
**Test Environment:** LambdaTest Real Device Cloud
**App Version:** NRTestApp 4.7

---

## 📊 Test Data

### Baseline (Session Replay OFF)
- **Average Memory:** 148.51 MB
- **Peak Memory:** 174.11 MB
- **Memory Range:** 66.64 MB
- **Average CPU:** 22.33%
- **Peak CPU:** 86.8%
- **Startup Time:** 328ms
- **Test Duration:** 294 seconds (~5 minutes)
- **Metrics Collected:** 147 samples

### With Session Replay (Session Replay ON)
- **Average Memory:** 160.61 MB
- **Peak Memory:** 192.83 MB
- **Memory Range:** 81.17 MB
- **Average CPU:** 24.16%
- **Peak CPU:** 88.7%
- **Startup Time:** 229ms
- **Test Duration:** 296 seconds (~5 minutes)
- **Metrics Collected:** 148 samples

---

## 🎯 Session Replay Overhead

### Memory Impact
| Metric | Overhead | Percentage |
|--------|----------|------------|
| Average Memory | +12.1 MB | +8.15% |
| Peak Memory | +18.72 MB | +10.75% |
| Memory Range | +14.53 MB | +21.8% |

### CPU Impact
| Metric | Overhead | Percentage |
|--------|----------|------------|
| Average CPU | +1.83% | +8.2% |
| Peak CPU | +1.9% | +2.19% |

### Startup Impact
| Metric | Overhead | Percentage |
|--------|----------|------------|
| Startup Time | -99ms | -30.18% (faster) |

---

## 📈 Summary

Session Replay adds approximately:
- **8.15% memory overhead** (average)
- **8.2% CPU overhead** (average)
- **No startup time penalty** (actually faster in this test)

The overhead is minimal and within acceptable limits for production use.

---

## 🧪 Test Methodology

### Test Scenario
The test performed the following intensive operations:
1. **Navigation Stress Test** (5 iterations)
   - Navigate to Utilities screen
   - Navigate back to main screen
   - Wait 500ms between operations

2. **Infinite Scroll Test**
   - 4 scrolls down
   - 2 scrolls up
   - Tests continuous scroll event capture

3. **Image Collection Scroll Test**
   - 4 scrolls through image collections
   - Tests visual content capture with scrolling

4. **SwiftUI Interactions**
   - 2 SwiftUI examples tested
   - Up to 3 button taps per example
   - Scrolling within SwiftUI views

5. **Metrics Collection**
   - Resource metrics collected every 2 seconds
   - Memory usage (MB) via mach APIs
   - CPU usage (%) via thread_basic_info
   - PerformanceSuite metrics (startup, TTI, health checks)

### Configuration
- **Device:** Real iOS device (LambdaTest)
- **Test Framework:** WebDriverIO + Appium
- **Metrics Library:** PerformanceSuite
- **Test Duration:** ~5 minutes per test
- **Samples Collected:** 147-148 samples per test
- **Baseline:** Session Replay disabled via environment variable
- **With Session Replay:** Session Replay enabled via environment variable

---

## 🔍 Health Check Results

Both tests showed:
- **Fatal Hangs:** 0
- **Memory Leaks:** 0
- **Test Status:** ✅ All tests passed

---

## ✅ Verdict

**SESSION REPLAY OVERHEAD IS ACCEPTABLE**

All metrics are within acceptable thresholds:
- ✅ Average memory overhead (12.1 MB) is within limits
- ✅ Memory overhead percentage (8.15%) is within limits (< 25%)
- ✅ CPU overhead (8.2%) is within limits (< 15%)
- ✅ No stability issues detected

Session Replay is **suitable for production use** with minimal performance impact.

---

*Generated from automated performance testing on LambdaTest Real Device Cloud*
