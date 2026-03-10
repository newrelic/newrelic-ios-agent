import React, {useState} from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  Alert,
  NativeModules,
  Switch,
} from 'react-native';

const {NRTestBridge} = NativeModules;

const UtilitiesScreen: React.FC = () => {
  const [sessionId, setSessionId] = useState<string>('');
  const [interactionId, setInteractionId] = useState<string>('');
  const [networkEnabled, setNetworkEnabled] = useState(true);
  const [crashReportingEnabled, setCrashReportingEnabled] = useState(true);

  // Bridge Test
  const testPing = async () => {
    try {
      const result = await NRTestBridge.ping();
      Alert.alert('Bridge Test', `✅ ${result.status}`);
    } catch (error) {
      Alert.alert('Error', 'Bridge not working');
    }
  };

  // Events & Breadcrumbs
  const testCustomEvent = () => {
    NRTestBridge.recordCustomEvent('TestEvent', 'ButtonPressed', {
      testAttribute: 'test value',
      timestamp: Date.now(),
      platform: 'iOS',
      screen: 'Utilities',
    });
    Alert.alert('Success', 'Custom event recorded!');
  };

  const testBreadcrumb = () => {
    NRTestBridge.recordBreadcrumb('UserAction', {
      action: 'Test Breadcrumb',
      screen: 'UtilitiesScreen',
      timestamp: new Date().toISOString(),
    });
    Alert.alert('Success', 'Breadcrumb recorded!');
  };

  const testConsoleLog = () => {
    NRTestBridge.nativeLog('TestLog', 'Console log test from Utilities');
    Alert.alert('Success', 'Console log recorded!');
  };

  // Error Testing
  const testJSError = () => {
    NRTestBridge.recordStack(
      'TestJSError',
      'TestJSError',
      'Test error from Utilities screen',
      'at UtilitiesScreen.tsx:50\nat App.tsx:10',
      false,
      '1.0.0',
    );
    Alert.alert('Success', 'JS error recorded!');
  };

  const testHandledException = () => {
    const exceptionDict = {
      name: 'TestException',
      message: 'Test handled exception',
      isFatal: false,
      JSAppVersion: '1.0.0',
      stackFrames: {
        '0': {
          file: 'UtilitiesScreen.tsx',
          lineNumber: 60,
          methodName: 'testHandledException',
        },
        '1': {
          file: 'App.tsx',
          lineNumber: 100,
          methodName: 'handlePress',
        },
      },
    };
    NRTestBridge.recordHandledException(exceptionDict);
    Alert.alert('Success', 'Handled exception recorded!');
  };

  // Mobile Errors Protocol - Manual Test
  const testMobileJSErrorManual = () => {
    const stackTrace = `TypeError: Cannot read property 'foo' of undefined
    at UtilitiesScreen.testMobileJSError (UtilitiesScreen.tsx:95:12)
    at TouchableOpacity.onPress (UtilitiesScreen.tsx:350:45)
    at App.handlePress (App.tsx:100:20)
    at React.render (index.js:15:8)`;

    NRTestBridge.recordJavascriptError(
      'TypeError',
      "Cannot read property 'foo' of undefined",
      stackTrace,
      false,
      '1.0.0',
      {
        testType: 'manual',
        component: 'UtilitiesScreen',
        platform: 'iOS',
        timestamp: Date.now(),
      },
    );
    Alert.alert(
      'MobileJSError Recorded (Manual)',
      'Check New Relic for:\n• MobileJSError event\n• /mobile/errors endpoint\n• URL-encoded stack trace',
    );
  };

  // Mobile Errors Protocol - Real Error Test
  const testMobileJSErrorReal = () => {
    try {
      // Intentionally cause a real error
      const obj: any = null;
      obj.someProperty.foo.bar(); // Will throw TypeError
    } catch (error: any) {
      console.log('Caught error:', error);

      NRTestBridge.recordJavascriptError(
        error.name || 'Error',
        error.message || 'Unknown error',
        error.stack || 'No stack trace available',
        false,
        '1.0.0',
        {
          testType: 'real',
          caught: 'try-catch',
          screen: 'Utilities',
          errorType: typeof error,
        },
      );

      Alert.alert(
        'Real Error Caught & Recorded',
        `Error: ${error.message}\n\nCheck console for full details`,
      );
    }
  };

  // Mobile Errors Protocol - Fatal Error Test
  const testFatalJSError = () => {
    const stackTrace = `ReferenceError: x is not defined
    at UtilitiesScreen.testFatalJSError (UtilitiesScreen.tsx:125:5)
    at criticalFunction (utils.js:42:10)
    at App.componentDidCatch (App.tsx:50:15)`;

    NRTestBridge.recordJavascriptError(
      'ReferenceError',
      'x is not defined - simulating fatal crash',
      stackTrace,
      true, // isFatal = true
      '1.0.0',
      {
        testType: 'fatal',
        severity: 'critical',
        component: 'UtilitiesScreen',
      },
    );
    Alert.alert(
      'Fatal Error Recorded',
      'isFatal=true\n\nShould trigger immediate harvest if configured for fatal errors.',
    );
  };

  const testCrash = () => {
    Alert.alert(
      'Crash Test',
      'This will crash the app. Continue?',
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Crash',
          style: 'destructive',
          onPress: () => NRTestBridge.crashNow('Test crash from Utilities'),
        },
      ],
    );
  };

  // Attributes
  const testSetAttributes = () => {
    NRTestBridge.setStringAttribute('testString', 'Hello from Utilities');
    NRTestBridge.setNumberAttribute('testNumber', 42);
    NRTestBridge.setBoolAttribute('testBool', true);
    Alert.alert('Success', 'Attributes set!');
  };

  const testIncrementAttribute = () => {
    NRTestBridge.incrementAttribute('testCounter', 1);
    Alert.alert('Success', 'Attribute incremented!');
  };

  const testLogAttributes = () => {
    NRTestBridge.logAttributes({
      loggedAttr1: 'value1',
      loggedAttr2: 123,
      loggedAttr3: true,
    });
    Alert.alert('Success', 'Attributes logged!');
  };

  const testRemoveAttribute = () => {
    NRTestBridge.removeAttribute('testString');
    Alert.alert('Success', 'Attribute removed!');
  };

  const testRemoveAllAttributes = () => {
    NRTestBridge.removeAllAttributes();
    Alert.alert('Success', 'All attributes removed!');
  };

  const testSetUserId = () => {
    NRTestBridge.setUserId('test-user-123');
    Alert.alert('Success', 'User ID set to test-user-123');
  };

  const testSetJSAppVersion = () => {
    NRTestBridge.setJSAppVersion('1.2.3-test');
    Alert.alert('Success', 'JS App Version set!');
  };

  // Session & Interactions
  const getSessionId = async () => {
    try {
      const id = await NRTestBridge.currentSessionId();
      setSessionId(id);
      Alert.alert('Session ID', id);
    } catch (error) {
      Alert.alert('Error', 'Could not get session ID');
    }
  };

  const testStartInteraction = async () => {
    try {
      const id = await NRTestBridge.startInteraction('TestInteraction');
      setInteractionId(id);
      Alert.alert('Success', `Interaction started`);
    } catch (error) {
      Alert.alert('Error', 'Could not start interaction');
    }
  };

  const testEndInteraction = () => {
    if (interactionId) {
      NRTestBridge.endInteraction(interactionId);
      Alert.alert('Success', 'Interaction ended!');
      setInteractionId('');
    } else {
      Alert.alert('Info', 'No interaction to end');
    }
  };

  // Network Testing
  const testHttpSuccess = () => {
    const startTime = Date.now() / 1000;
    const endTime = startTime + 0.5;

    NRTestBridge.noticeHttpTransaction(
      'https://api.example.com/success',
      'GET',
      200,
      startTime,
      endTime,
      1024,
      2048,
      '{"status":"success"}',
    );
    Alert.alert('Success', 'HTTP 200 transaction recorded!');
  };

  const testHttpError = () => {
    const startTime = Date.now() / 1000;
    const endTime = startTime + 1.0;

    NRTestBridge.noticeHttpTransaction(
      'https://api.example.com/error',
      'POST',
      500,
      startTime,
      endTime,
      512,
      0,
      '{"error":"Internal Server Error"}',
    );
    Alert.alert('Success', 'HTTP 500 error recorded!');
  };

  const testNetworkFailure = () => {
    const startTime = Date.now() / 1000;
    const endTime = startTime + 2.0;

    NRTestBridge.noticeNetworkFailure(
      'https://api.example.com/timeout',
      'GET',
      startTime,
      endTime,
      'TimedOut',
    );
    Alert.alert('Success', 'Network failure recorded!');
  };

  const testAddHTTPHeaders = () => {
    NRTestBridge.addHTTPHeadersTrackingFor(['X-Custom-Header', 'Authorization']);
    Alert.alert('Success', 'HTTP headers tracking added!');
  };

  // Metrics
  const testRecordMetric = () => {
    NRTestBridge.recordMetric('TestMetric', 'Custom', 100, null, null);
    Alert.alert('Success', 'Metric recorded!');
  };

  const testRecordMetricWithUnits = () => {
    NRTestBridge.recordMetric(
      'MemoryUsage',
      'Performance',
      1024,
      'BYTES',
      'BYTES',
    );
    Alert.alert('Success', 'Metric with units recorded!');
  };

  // Configuration
  const testSetMaxEventPoolSize = () => {
    NRTestBridge.setMaxEventPoolSize(1000);
    Alert.alert('Success', 'Max event pool size set to 1000');
  };

  const testSetMaxEventBufferTime = () => {
    NRTestBridge.setMaxEventBufferTime(60);
    Alert.alert('Success', 'Max event buffer time set to 60s');
  };

  const testSetMaxOfflineStorageSize = () => {
    NRTestBridge.setMaxOfflineStorageSize(100);
    Alert.alert('Success', 'Max offline storage set to 100MB');
  };

  // Feature Flags
  const toggleNetworkTracking = (value: boolean) => {
    setNetworkEnabled(value);
    NRTestBridge.networkRequestEnabled(value);
    NRTestBridge.networkErrorRequestEnabled(value);
  };

  const toggleCrashReporting = (value: boolean) => {
    setCrashReportingEnabled(value);
    // Note: Can't enable/disable crash reporting after start in production
    Alert.alert('Info', 'Crash reporting toggle recorded');
  };

  const testEnableHTTPBodyCapture = () => {
    NRTestBridge.httpResponseBodyCaptureEnabled(true);
    Alert.alert('Success', 'HTTP body capture enabled!');
  };

  // Utility
  const testShutdown = () => {
    Alert.alert(
      'Shutdown Agent',
      'This will stop the agent. Continue?',
      [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Shutdown',
          style: 'destructive',
          onPress: () => {
            NRTestBridge.shutdown();
            Alert.alert('Success', 'Agent shut down!');
          },
        },
      ],
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>New Relic Utilities</Text>
          <Text style={styles.headerSubtitle}>Comprehensive testing tools</Text>
        </View>

        {sessionId ? (
          <View style={styles.infoCard}>
            <Text style={styles.infoText}>
              Session: {sessionId.substring(0, 16)}...
            </Text>
            {interactionId ? (
              <Text style={styles.infoText}>
                Interaction: {interactionId.substring(0, 16)}...
              </Text>
            ) : null}
          </View>
        ) : null}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Bridge</Text>
          <TouchableOpacity style={styles.button} onPress={testPing}>
            <Text style={styles.buttonText}>Ping Bridge</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Events & Breadcrumbs</Text>
          <TouchableOpacity style={styles.button} onPress={testCustomEvent}>
            <Text style={styles.buttonText}>Record Custom Event</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testBreadcrumb}>
            <Text style={styles.buttonText}>Record Breadcrumb</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testConsoleLog}>
            <Text style={styles.buttonText}>Record Console Log</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Error Testing</Text>
          <TouchableOpacity style={styles.button} onPress={testJSError}>
            <Text style={styles.buttonText}>Record JS Error (Old)</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testHandledException}>
            <Text style={styles.buttonText}>Record Handled Exception</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.button, styles.dangerButton]} onPress={testCrash}>
            <Text style={styles.buttonText}>⚠️ Test Crash</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Mobile Errors Protocol</Text>
          <TouchableOpacity style={styles.button} onPress={testMobileJSErrorManual}>
            <Text style={styles.buttonText}>📝 MobileJSError (Manual)</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testMobileJSErrorReal}>
            <Text style={styles.buttonText}>💥 MobileJSError (Real Error)</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.button, styles.warningButton]} onPress={testFatalJSError}>
            <Text style={styles.buttonText}>☠️ Fatal JS Error</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Attributes</Text>
          <TouchableOpacity style={styles.button} onPress={testSetAttributes}>
            <Text style={styles.buttonText}>Set Attributes</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testIncrementAttribute}>
            <Text style={styles.buttonText}>Increment Attribute</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testLogAttributes}>
            <Text style={styles.buttonText}>Log Attributes</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testRemoveAttribute}>
            <Text style={styles.buttonText}>Remove Attribute</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testRemoveAllAttributes}>
            <Text style={styles.buttonText}>Remove All Attributes</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testSetUserId}>
            <Text style={styles.buttonText}>Set User ID</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testSetJSAppVersion}>
            <Text style={styles.buttonText}>Set JS App Version</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Session & Interactions</Text>
          <TouchableOpacity style={styles.button} onPress={getSessionId}>
            <Text style={styles.buttonText}>Get Session ID</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testStartInteraction}>
            <Text style={styles.buttonText}>Start Interaction</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.button, !interactionId && styles.buttonDisabled]}
            onPress={testEndInteraction}
            disabled={!interactionId}>
            <Text style={[styles.buttonText, !interactionId && styles.buttonTextDisabled]}>
              End Interaction
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Network Testing</Text>
          <TouchableOpacity style={styles.button} onPress={testHttpSuccess}>
            <Text style={styles.buttonText}>HTTP 200 Success</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testHttpError}>
            <Text style={styles.buttonText}>HTTP 500 Error</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testNetworkFailure}>
            <Text style={styles.buttonText}>Network Timeout</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testAddHTTPHeaders}>
            <Text style={styles.buttonText}>Track HTTP Headers</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Metrics</Text>
          <TouchableOpacity style={styles.button} onPress={testRecordMetric}>
            <Text style={styles.buttonText}>Record Simple Metric</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testRecordMetricWithUnits}>
            <Text style={styles.buttonText}>Record Metric with Units</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Configuration</Text>
          <TouchableOpacity style={styles.button} onPress={testSetMaxEventPoolSize}>
            <Text style={styles.buttonText}>Set Max Event Pool Size</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testSetMaxEventBufferTime}>
            <Text style={styles.buttonText}>Set Max Buffer Time</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={testSetMaxOfflineStorageSize}>
            <Text style={styles.buttonText}>Set Max Offline Storage</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Feature Flags</Text>
          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Network Tracking</Text>
            <Switch value={networkEnabled} onValueChange={toggleNetworkTracking} />
          </View>
          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Crash Reporting</Text>
            <Switch value={crashReportingEnabled} onValueChange={toggleCrashReporting} />
          </View>
          <TouchableOpacity style={styles.button} onPress={testEnableHTTPBodyCapture}>
            <Text style={styles.buttonText}>Enable HTTP Body Capture</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Utility</Text>
          <TouchableOpacity style={[styles.button, styles.dangerButton]} onPress={testShutdown}>
            <Text style={styles.buttonText}>⚠️ Shutdown Agent</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    paddingBottom: 30,
  },
  header: {
    backgroundColor: '#fff',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  infoCard: {
    backgroundColor: '#e8f5e9',
    padding: 15,
    margin: 15,
    borderRadius: 8,
  },
  infoText: {
    fontSize: 12,
    color: '#2e7d32',
    marginVertical: 2,
  },
  section: {
    backgroundColor: '#fff',
    marginTop: 15,
    padding: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 15,
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 10,
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  dangerButton: {
    backgroundColor: '#FF3B30',
  },
  warningButton: {
    backgroundColor: '#FF9500',
  },
  buttonText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '500',
  },
  buttonTextDisabled: {
    color: '#666',
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  switchLabel: {
    fontSize: 16,
    color: '#333',
  },
});

export default UtilitiesScreen;
