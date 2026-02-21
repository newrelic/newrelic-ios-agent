import React from 'react';
import {View, Text, StyleSheet, SafeAreaView, ScrollView} from 'react-native';

const HomeScreen: React.FC = () => {
  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.title}>New Relic Test App</Text>
          <Text style={styles.subtitle}>React Native iOS Agent Testing</Text>
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>✓ Setup Complete</Text>
          <Text style={styles.cardText}>
            • Bridge module connected{'\n'}
            • Local iOS Agent linked{'\n'}
            • Ready for testing
          </Text>
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Available Screens</Text>
          <Text style={styles.cardText}>
            <Text style={styles.bold}>Lists:</Text> Test ScrollViews and FlatLists{'\n'}
            <Text style={styles.bold}>Forms:</Text> Test inputs and interactions{'\n'}
            <Text style={styles.bold}>Utilities:</Text> New Relic test functions
          </Text>
        </View>

        <View style={styles.infoCard}>
          <Text style={styles.infoTitle}>Session Replay Testing</Text>
          <Text style={styles.infoText}>
            Navigate through screens and interact with components to test how
            Session Replay captures user interactions.
          </Text>
        </View>

        <View style={styles.versionCard}>
          <Text style={styles.versionText}>React Native 0.76.5</Text>
          <Text style={styles.versionText}>Testing Local iOS Agent</Text>
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
    padding: 20,
  },
  header: {
    alignItems: 'center',
    marginVertical: 30,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 10,
  },
  cardText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 22,
  },
  bold: {
    fontWeight: '600',
    color: '#333',
  },
  infoCard: {
    backgroundColor: '#e3f2fd',
    borderRadius: 12,
    padding: 20,
    marginBottom: 15,
  },
  infoTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1976d2',
    marginBottom: 8,
  },
  infoText: {
    fontSize: 14,
    color: '#1565c0',
    lineHeight: 20,
  },
  versionCard: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 15,
    alignItems: 'center',
    marginTop: 10,
  },
  versionText: {
    fontSize: 12,
    color: '#999',
    marginVertical: 2,
  },
});

export default HomeScreen;
