# Session Replay Performance Test Results

**Test Date:** March 26, 2026
**Platform:** iOS - Real Device (LambdaTest)
**Test Environment:** LambdaTest Real Device Cloud
**App Version:** NRTestApp 4.7

---

## 📊 Test Data

| Metric | No Agent | Agent Baseline | Agent + Session Replay |
|--------|----------|----------------------|------------------------|
| **Average Memory** | 132.67 MB | 144.98 MB | 164.10 MB |
| **Peak Memory** | 165.16 MB | 174.48 MB | 203.48 MB |
| **Memory Range** | 64.49 MB | 64.73 MB | 88.53 MB |
| **Average CPU** | 23.07% | 22.59% | 24.97% |
| **Peak CPU** | 90.10% | 89.5% | 90.4% |
| **Test Duration** | 274s (~4.5 min) | 252s (~4 min) | 268s (~4.5 min) |
| **Samples Collected** | 137 | 126 | 134 |
| **Health** | ✅ 0 hangs, 0 leaks | ✅ 0 hangs, 0 leaks | ✅ 0 hangs, 0 leaks |

---

## 🎯 Session Replay Overhead

**Comparison:** Agent Baseline vs Agent + Session Replay

This measures the **incremental overhead** of enabling Session Replay on top of the New Relic agent.

### Memory Impact
| Metric | Agent Baseline | Agent + SR | Overhead | % Increase |
|--------|------------|------------|----------|------------|
| Average Memory | 144.98 MB | 164.10 MB | **+19.12 MB** | **+13.19%** |
| Peak Memory | 174.48 MB | 203.48 MB | **+29.00 MB** | **+16.62%** |
| Memory Range | 64.73 MB | 88.53 MB | +23.80 MB | +36.77% |

### CPU Impact
| Metric | Agent Baseline | Agent + SR | Overhead | % Increase |
|--------|------------|------------|----------|------------|
| Average CPU | 22.59% | 24.97% | **+2.38%** | **+10.54%** |
| Peak CPU | 89.5% | 90.4% | +0.9% | +1.01% |

---

## 📈 Summary

**Session Replay incremental overhead** (when added to an app already using the New Relic agent):
- **+19.12 MB memory** (+13.19% increase)
- **+2.38% CPU usage** (+10.54% increase)

The overhead is minimal and within acceptable limits for production use.

---

## 🔬 Three-Way Comparison (No Agent vs Agent vs Agent + Session Replay)

To understand the incremental overhead of each component, we tested three configurations:
1. **No Agent** - Pure app without New Relic agent
2. **Agent Baseline** - New Relic agent enabled, Session Replay disabled
3. **Agent + Session Replay** - Both agent and Session Replay enabled

### Performance Metrics Across All Configurations

| Metric | No Agent | Agent Baseline | Agent + SR |
|--------|---------------------|------------|------------|
| **Avg Memory** | 132.67 MB | 144.98 MB | 164.10 MB |
| **Peak Memory** | 165.16 MB | 174.48 MB | 203.48 MB |
| **Avg CPU** | 23.07% | 22.59% | 24.97% |
| **Peak CPU** | 90.10% | 89.5% | 90.4% |
| **Samples** | 137 | 126 | 134 |
| **Duration** | ~274s | ~252s | ~268s |

### Incremental Overhead Breakdown

This table shows how each component adds overhead, building from the pure app (No Agent):

| Metric | Step 1: Agent Overhead<br>(vs No Agent) | Step 2: Session Replay Overhead<br>(vs Agent Only) | **Total Overhead**<br>**(vs No Agent)** |
|--------|------------------------------------------|-----------------------------------------------------|------------------------------------------|
| **Average Memory** | +12.31 MB<br>(+9.28%) | +19.12 MB<br>(+13.19%) | **+31.43 MB<br>(+23.69%)** |
| **Peak Memory** | +9.32 MB<br>(+5.64%) | +29.00 MB<br>(+16.62%) | **+38.32 MB<br>(+23.20%)** |
| **Average CPU** | -0.48%<br>(-2.08%) | +2.38%<br>(+10.54%) | **+1.90%<br>(+8.24%)** |
| **Peak CPU** | -0.60%<br>(-0.67%) | +0.90%<br>(+1.01%) | **+0.30%<br>(+0.33%)** |

**Reading this table:**
- **Step 1 (Agent):** Overhead when adding the New Relic agent to the pure app (No Agent)
- **Step 2 (Session Replay):** Additional overhead when enabling Session Replay on top of Agent Baseline
- **Total:** Combined overhead of agent + Session Replay vs pure app (No Agent)

### Key Insights

1. **Agent Overhead**: The New Relic agent itself adds ~12 MB memory with negligible CPU impact (vs No Agent)
2. **Session Replay Incremental**: Session Replay adds an additional ~19 MB memory and ~2.4% CPU on top of Agent Baseline
3. **Combined Impact**: Total overhead is ~31 MB (24%) memory and ~2% (8%) CPU vs pure app (No Agent)
4. **Production Ready**: Both agent and Session Replay overheads are within acceptable limits for production use
5. **No Stability Issues**: Zero hangs or memory leaks across all three configurations

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
   - 3 SwiftUI examples tested
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
- **Test Duration:** ~4-5 minutes per test
- **Samples Collected:** 126-137 samples per test
- **No Agent:** Pure app without New Relic agent (NO_AGENT=1)
- **Agent Baseline:** Agent enabled, Session Replay disabled (BASELINE=1)
- **Agent + Session Replay:** Agent enabled, Session Replay enabled via environment variable

---

## 🔍 Health Check Results

All three tests showed:
- **Fatal Hangs:** 0
- **Memory Leaks:** 0
- **Test Status:** ✅ All tests passed

---

## ✅ Verdict

**SESSION REPLAY OVERHEAD IS ACCEPTABLE**

All metrics are within acceptable thresholds:
- ✅ Average memory overhead (19.12 MB) is within limits (< 50 MB)
- ✅ Memory overhead percentage (13.19%) is within limits (< 25%)
- ✅ CPU overhead (10.54%) is within limits (< 15%)
- ✅ No stability issues detected

---

*Generated from automated performance testing on LambdaTest Real Device Cloud*
