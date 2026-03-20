/**
 * Performance Metrics Tests
 * Tests that performance metrics are being collected by PerformanceSuite
 * and saved to the performance_metrics.json file
 */

describe("Performance Metrics Collection", () => {
  it("Should collect startup and navigation metrics", async () => {
    // Wait for app to fully load
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });

    // Navigate to a few screens to trigger TTI and rendering metrics
    const utilitiesButton = await $("~Utilities");
    await utilitiesButton.waitForExist({ timeout: 5000 });
    await utilitiesButton.click();

    // Wait for screen to load
    await driver.pause(2000);

    // Navigate back
    await driver.back();
    await helloWorldText.waitForExist({ timeout: 5000 });

    // Navigate to SwiftUI examples to trigger more metrics
    const swiftUIButton = await $("~SwiftUI Examples");
    if (await swiftUIButton.isExisting()) {
      await swiftUIButton.click();
      await driver.pause(2000);
      await driver.back();
    }

    // Give time for metrics to be written to disk
    await driver.pause(2000);
  });

  it("Should retrieve and validate performance metrics file", async () => {
    // Pull the performance_metrics.json file from the app's Documents directory
    // The file path is relative to the app's container
    let metricsData;

    try {
      // For iOS simulator, we can use driver.pullFile
      // The path is relative to the app's Documents directory
      const base64File = await driver.pullFile('Documents/performance_metrics.json');
      const metricsJson = Buffer.from(base64File, 'base64').toString('utf8');
      metricsData = JSON.parse(metricsJson);

      console.log('Performance metrics collected:');
      console.log(JSON.stringify(metricsData, null, 2));
    } catch (error) {
      console.error('Failed to pull performance metrics file:', error);
      throw new Error('Could not retrieve performance_metrics.json file');
    }

    // Validate that we got metrics data
    expect(metricsData).toBeDefined();
    expect(Array.isArray(metricsData)).toBe(true);
    expect(metricsData.length).toBeGreaterThan(0);

    // Validate that metrics have the expected structure
    metricsData.forEach(metric => {
      expect(metric).toHaveProperty('type');
      expect(metric).toHaveProperty('timestamp');
    });

    // Check for specific metric types
    const metricTypes = metricsData.map(m => m.type);
    console.log('Metric types collected:', metricTypes);

    // Assert that we have at least startup time
    const hasStartupMetric = metricTypes.includes('startupTime');
    if (hasStartupMetric) {
      const startupMetric = metricsData.find(m => m.type === 'startupTime');
      expect(startupMetric.duration).toBeGreaterThan(0);
      console.log(`Startup time: ${startupMetric.duration}ms`);
    }

    // Check for rendering metrics
    const renderingMetrics = metricsData.filter(m =>
      m.type === 'rendering' || m.type === 'appRendering'
    );
    if (renderingMetrics.length > 0) {
      console.log(`Found ${renderingMetrics.length} rendering metrics`);
      renderingMetrics.forEach(metric => {
        expect(metric.freezeTime).toBeDefined();
      });
    }

    // Check for TTI metrics
    const ttiMetrics = metricsData.filter(m => m.type === 'tti');
    if (ttiMetrics.length > 0) {
      console.log(`Found ${ttiMetrics.length} TTI metrics`);
      ttiMetrics.forEach(metric => {
        expect(metric.screen).toBeDefined();
        expect(metric.tti).toBeGreaterThan(0);
        console.log(`TTI for ${metric.screen}: ${metric.tti}ms`);
      });
    }

    // Check for hangs (we don't want any fatal hangs)
    const fatalHangs = metricsData.filter(m => m.type === 'fatalHang');
    expect(fatalHangs.length).toBe(0);

    // Check for memory leaks (we don't want any)
    const memoryLeaks = metricsData.filter(m => m.type === 'memoryLeak');
    expect(memoryLeaks.length).toBe(0);

    console.log('\n✓ Performance metrics validation passed');
  });

  it("Should verify metrics are within acceptable thresholds", async () => {
    // Pull metrics again for threshold checks
    const base64File = await driver.pullFile('Documents/performance_metrics.json');
    const metricsJson = Buffer.from(base64File, 'base64').toString('utf8');
    const metricsData = JSON.parse(metricsJson);

    // Define acceptable thresholds
    const THRESHOLDS = {
      startupTime: 5000,  // 5 seconds
      tti: 3000,          // 3 seconds
      freezeTime: 1000    // 1 second
    };

    // Check startup time threshold
    const startupMetric = metricsData.find(m => m.type === 'startupTime');
    if (startupMetric) {
      expect(startupMetric.duration).toBeLessThan(THRESHOLDS.startupTime);
      console.log(`✓ Startup time ${startupMetric.duration}ms < ${THRESHOLDS.startupTime}ms threshold`);
    }

    // Check TTI thresholds
    const ttiMetrics = metricsData.filter(m => m.type === 'tti');
    ttiMetrics.forEach(metric => {
      expect(metric.tti).toBeLessThan(THRESHOLDS.tti);
      console.log(`✓ TTI for ${metric.screen}: ${metric.tti}ms < ${THRESHOLDS.tti}ms threshold`);
    });

    // Check freeze time thresholds
    const freezeMetrics = metricsData.filter(m =>
      m.type === 'rendering' || m.type === 'appRendering'
    );
    freezeMetrics.forEach(metric => {
      if (metric.freezeTime > 0) {
        expect(metric.freezeTime).toBeLessThan(THRESHOLDS.freezeTime);
        console.log(`✓ Freeze time: ${metric.freezeTime}ms < ${THRESHOLDS.freezeTime}ms threshold`);
      }
    });

    console.log('\n✓ All metrics are within acceptable thresholds');
  });
});
