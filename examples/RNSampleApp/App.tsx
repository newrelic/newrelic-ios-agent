import React, {useState} from 'react';
import {StyleSheet, View} from 'react-native';
import HomeScreen from './src/screens/HomeScreen';
import ListsScreen from './src/screens/ListsScreen';
import FormsScreen from './src/screens/FormsScreen';
import UtilitiesScreen from './src/screens/UtilitiesScreen';
import DetailScreen from './src/screens/DetailScreen';
import TabBar from './src/components/TabBar';

type TabName = 'Home' | 'Lists' | 'Forms' | 'Utilities';

export interface ListItem {
  id: string;
  title: string;
  subtitle: string;
  type: string;
}

function App(): React.JSX.Element {
  const [activeTab, setActiveTab] = useState<TabName>('Home');
  const [selectedItem, setSelectedItem] = useState<ListItem | null>(null);

  const handleItemPress = (item: ListItem) => {
    setSelectedItem(item);
  };

  const handleBackPress = () => {
    setSelectedItem(null);
  };

  const renderScreen = () => {
    // Show detail screen if item is selected
    if (selectedItem) {
      return (
        <DetailScreen item={selectedItem} onBackPress={handleBackPress} />
      );
    }

    // Otherwise show the tab screen
    switch (activeTab) {
      case 'Home':
        return <HomeScreen />;
      case 'Lists':
        return <ListsScreen onItemPress={handleItemPress} />;
      case 'Forms':
        return <FormsScreen />;
      case 'Utilities':
        return <UtilitiesScreen />;
      default:
        return <HomeScreen />;
    }
  };

  return (
    <View style={styles.container}>
      {renderScreen()}
      {!selectedItem && <TabBar activeTab={activeTab} onTabPress={setActiveTab} />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
});

export default App;
