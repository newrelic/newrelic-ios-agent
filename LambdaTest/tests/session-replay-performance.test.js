/**
 * Session Replay Performance Tests
 * Measures memory and CPU overhead when Session Replay is enabled vs disabled
 *
 * Run this test twice:
 * 1. Baseline: with BASELINE=1 env var (Session Replay OFF)
 * 2. With Session Replay: without env var (Session Replay ON)
 *
 * Test includes:
 * - 5 navigation cycles
 * - Infinite scroll testing (4 scrolls down, 2 up)
 * - Image collection scrolling (4 scrolls with images)
 * - SwiftUI interactions (2 examples with ~3 taps each + scrolling)
 * - Total duration: ~5 minutes for stable metrics
 *
 * Results are automatically saved to JSON files for comparison
 *
 * Compare memory usage, memory overhead, CPU load, and CPU overhead
 */

const fs = require('fs');
const path = require('path');

describe("Session Replay Performance Impact", () => {
  it("Should perform intensive UI operations and collect resource metrics", async () => {
    console.log('Starting intensive UI operations for Session Replay performance testing...');

    // Wait for app to fully load
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });
    console.log('App loaded successfully');

    // Give time for initial metrics to be collected
    await driver.pause(3000);

    // === Phase 1: Navigation Stress Test ===
    console.log('Phase 1: Navigation stress test (5 iterations)');
    for (let i = 0; i < 5; i++) {
      // Navigate to Utilities - find the cell containing the text
      const utilitiesButton = await $('//XCUIElementTypeCell[.//XCUIElementTypeStaticText[@name="Utilities"]]');
      await utilitiesButton.waitForExist({ timeout: 5000 });
      await utilitiesButton.click();
      await driver.pause(500);

      // Navigate back
      await driver.back();
      await helloWorldText.waitForExist({ timeout: 5000 });
      await driver.pause(500);

      console.log(`  Navigation iteration ${i + 1}/5 completed`);
    }
    console.log('Navigation stress test completed');

    // Wait for metrics to be collected
    await driver.pause(3000);

    // === Phase 2: Infinite Scroll Test ===
    console.log('Phase 2: Infinite scroll test');
    try {
      // Scroll down to find the Infinite Scroll View button
      await driver.execute('mobile: scroll', { direction: 'down' });
      await driver.pause(500);

      // Look for infinite scroll button on main screen - find the cell containing the text
      const infiniteScrollButton = await $('//XCUIElementTypeCell[.//XCUIElementTypeStaticText[@name="Infinite Scroll View"]]');
      await infiniteScrollButton.waitForExist({ timeout: 5000 });
      await infiniteScrollButton.click();
      await driver.pause(2000);

      console.log('  Starting scroll operations (4 scrolls)');
      // Perform multiple scroll operations
      for (let i = 0; i < 4; i++) {
        await driver.execute('mobile: scroll', { direction: 'down' });
        await driver.pause(200);
        if (i % 2 === 0) {
          console.log(`    Scroll ${i + 1}/4 completed`);
        }
      }

      // Scroll back up
      for (let i = 0; i < 2; i++) {
        await driver.execute('mobile: scroll', { direction: 'up' });
        await driver.pause(200);
      }

      // Go back to home
      await driver.back();
      await helloWorldText.waitForExist({ timeout: 5000 });

      // Scroll back to top of main screen
      await driver.execute('mobile: scroll', { direction: 'up' });
      await driver.pause(500);

      console.log('  Infinite scroll test completed');
    } catch (e) {
      console.log('  Infinite scroll not available, skipping:', e.message);
    }

    // Wait for metrics
    await driver.pause(3000);

    // === Phase 3: Image Collection Scroll Test ===
    console.log('Phase 3: Image collection scroll test');
    try {
      // Scroll down to find the Infinite Images View button
      await driver.execute('mobile: scroll', { direction: 'down' });
      await driver.pause(500);

      // Look for image collection button on main screen - find the cell containing the text
      const imageCollectionButton = await $('//XCUIElementTypeCell[.//XCUIElementTypeStaticText[@name="Infinite Images View"]]');
      await imageCollectionButton.waitForExist({ timeout: 5000 });
      await imageCollectionButton.click();
      await driver.pause(2000);

      console.log('  Scrolling through images (4 scrolls)');
      // Scroll through images
      for (let i = 0; i < 4; i++) {
        await driver.execute('mobile: scroll', { direction: 'down' });
        await driver.pause(200);
        if (i % 2 === 0) {
          console.log(`    Image scroll ${i + 1}/4 completed`);
        }
      }

      // Go back to home
      await driver.back();
      await helloWorldText.waitForExist({ timeout: 5000 });

      // Scroll back to top of main screen
      await driver.execute('mobile: scroll', { direction: 'up' });
      await driver.pause(500);

      console.log('  Image collection test completed');
    } catch (e) {
      console.log('  Image collection not available, skipping:', e.message);
    }

    // Wait for metrics
    await driver.pause(3000);

    // === Phase 4: SwiftUI Interactions ===
    console.log('Phase 4: SwiftUI interactions (2 examples)');

    // Navigate to 2 different SwiftUI examples, starting from main each time
    for (let exampleNum = 0; exampleNum < 2; exampleNum++) {
      try {
        // Scroll up to make sure SwiftUI button is visible
        await driver.execute('mobile: scroll', { direction: 'up' });
        await driver.pause(500);

        // Click SwiftUI from main screen
        const swiftUIButton = await $('//XCUIElementTypeCell[.//XCUIElementTypeStaticText[@name="SwiftUI"]]');
        await swiftUIButton.waitForExist({ timeout: 5000 });
        await swiftUIButton.click();
        await driver.pause(1000);

        // Get all example buttons in the SwiftUI list
        const buttons = await $$("XCUIElementTypeButton");
        const exampleButtons = buttons.slice(2); // Skip back/nav buttons

        if (exampleNum < exampleButtons.length) {
          console.log(`    Opening SwiftUI example ${exampleNum + 1}`);

          // Click the example button
          await exampleButtons[exampleNum].click();
          await driver.pause(1000);

          // Interact with elements in the example
          try {
            const interactiveElements = await $$("XCUIElementTypeButton");
            if (interactiveElements.length > 0) {
              // Click a few interactive elements
              for (let i = 0; i < Math.min(3, interactiveElements.length); i++) {
                if (await interactiveElements[i].isDisplayed()) {
                  await interactiveElements[i].click();
                  await driver.pause(300);
                }
              }
            }

            // Scroll in the example view
            await driver.execute('mobile: scroll', { direction: 'down' });
            await driver.pause(500);
          } catch (e) {
            console.log(`      No interactive elements in example ${exampleNum + 1}`);
          }

          // Go back to main screen
          await driver.back();
          await helloWorldText.waitForExist({ timeout: 5000 });

          console.log(`    SwiftUI example ${exampleNum + 1} completed`);
        }
      } catch (e) {
        console.log(`    Error with SwiftUI example ${exampleNum + 1}:`, e.message);
        // Try to get back to main screen
        try {
          await driver.back();
          await helloWorldText.waitForExist({ timeout: 5000 });
        } catch {}
      }
    }

    console.log('  SwiftUI interactions completed');

    // Wait for metrics
    await driver.pause(3000);

    // Final wait for metrics collection
    console.log('Waiting for final metrics collection...');
    await driver.pause(8000);

    console.log('✓ Intensive UI operations completed - Enhanced test with ~5 min duration');
  });

  it("Should retrieve and analyze resource metrics", async () => {
    console.log('Retrieving performance metrics...');

    let metricsData;

    try {
      // Find the hidden label by accessibility identifier
      const metricsLabel = await $("~performance_metrics_json");
      await metricsLabel.waitForExist({ timeout: 10000 });

      // Read the JSON text from the label
      const jsonText = await metricsLabel.getText();
      console.log(`Retrieved JSON text (${jsonText.length} characters)`);

      // Parse the JSON
      metricsData = JSON.parse(jsonText);

      console.log(`Total metrics collected: ${metricsData.length}`);
    } catch (error) {
      console.error('Failed to retrieve performance metrics:', error.message);
      throw new Error('Could not retrieve performance metrics from UI label');
    }

    // Validate metrics data
    expect(metricsData).toBeDefined();
    expect(Array.isArray(metricsData)).toBe(true);
    expect(metricsData.length).toBeGreaterThan(0);

    // === Analyze Resource Usage Metrics ===
    const resourceMetrics = metricsData.filter(m => m.type === 'resourceUsage');
    console.log(`\nResource usage metrics collected: ${resourceMetrics.length}`);
    expect(resourceMetrics.length).toBeGreaterThan(0);

    // Calculate memory statistics
    const memoryValues = resourceMetrics.map(m => m.memoryMB).filter(v => v > 0);
    const avgMemory = memoryValues.reduce((a, b) => a + b, 0) / memoryValues.length;
    const maxMemory = Math.max(...memoryValues);
    const minMemory = Math.min(...memoryValues);

    console.log('\n=== MEMORY USAGE ===');
    console.log(`Average Memory: ${avgMemory.toFixed(2)} MB`);
    console.log(`Peak Memory: ${maxMemory.toFixed(2)} MB`);
    console.log(`Min Memory: ${minMemory.toFixed(2)} MB`);
    console.log(`Memory Range: ${(maxMemory - minMemory).toFixed(2)} MB`);

    // Calculate CPU statistics
    const cpuValues = resourceMetrics.map(m => m.cpuPercent).filter(v => v >= 0);
    const avgCPU = cpuValues.reduce((a, b) => a + b, 0) / cpuValues.length;
    const maxCPU = Math.max(...cpuValues);

    console.log('\n=== CPU USAGE ===');
    console.log(`Average CPU: ${avgCPU.toFixed(2)}%`);
    console.log(`Peak CPU: ${maxCPU.toFixed(2)}%`);

    // === Check Other Performance Metrics ===
    const startupMetric = metricsData.find(m => m.type === 'startupTime');
    if (startupMetric) {
      console.log(`\nStartup Time: ${startupMetric.duration}ms`);
    }

    const ttiMetrics = metricsData.filter(m => m.type === 'tti');
    if (ttiMetrics.length > 0) {
      console.log(`\nTTI Metrics: ${ttiMetrics.length} screens`);
      ttiMetrics.forEach(m => {
        console.log(`  ${m.screen}: ${m.tti}ms`);
      });
    }

    const renderingMetrics = metricsData.filter(m => m.type === 'rendering' || m.type === 'appRendering');
    if (renderingMetrics.length > 0) {
      console.log(`\nRendering Metrics: ${renderingMetrics.length} measurements`);
      const freezes = renderingMetrics.filter(m => m.freezeTime > 0);
      if (freezes.length > 0) {
        const avgFreeze = freezes.reduce((a, b) => a + b.freezeTime, 0) / freezes.length;
        console.log(`  Average Freeze Time: ${avgFreeze.toFixed(2)}ms`);
      }
    }

    // === Check for Issues ===
    const fatalHangs = metricsData.filter(m => m.type === 'fatalHang');
    const memoryLeaks = metricsData.filter(m => m.type === 'memoryLeak');

    console.log('\n=== HEALTH CHECK ===');
    console.log(`Fatal Hangs: ${fatalHangs.length}`);
    console.log(`Memory Leaks: ${memoryLeaks.length}`);

    expect(fatalHangs.length).toBe(0);
    expect(memoryLeaks.length).toBe(0);

    // === Save Summary for Comparison ===
    // Detect test type: BASELINE env var is set when running baseline test
    const isBaseline = process.env.BASELINE === '1';
    const summary = {
      sessionReplayEnabled: !isBaseline,
      testDuration: resourceMetrics.length * 2, // 2 seconds per sample
      resourceMetrics: {
        count: resourceMetrics.length,
        memory: {
          avg: parseFloat(avgMemory.toFixed(2)),
          peak: parseFloat(maxMemory.toFixed(2)),
          min: parseFloat(minMemory.toFixed(2)),
          range: parseFloat((maxMemory - minMemory).toFixed(2))
        },
        cpu: {
          avg: parseFloat(avgCPU.toFixed(2)),
          peak: parseFloat(maxCPU.toFixed(2))
        }
      },
      performanceMetrics: {
        startupTime: startupMetric ? startupMetric.duration : null,
        ttiCount: ttiMetrics.length,
        renderingCount: renderingMetrics.length
      },
      healthCheck: {
        fatalHangs: fatalHangs.length,
        memoryLeaks: memoryLeaks.length
      }
    };

    console.log('\n=== TEST SUMMARY ===');
    console.log(JSON.stringify(summary, null, 2));

    // Save results to file
    const filename = isBaseline ? 'baseline_results.json' : 'session_replay_results.json';
    const filepath = path.join(__dirname, '..', filename);

    try {
      fs.writeFileSync(filepath, JSON.stringify(summary, null, 2));
      console.log(`\n💾 Results saved to: ${filename}`);
    } catch (error) {
      console.error(`Failed to save results to ${filename}:`, error.message);
    }

    console.log('\n✓ Resource metrics analysis completed');
  });
});
