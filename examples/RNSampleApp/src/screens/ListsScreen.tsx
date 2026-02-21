import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  FlatList,
  TouchableOpacity,
  Image,
} from 'react-native';
import {ListItem} from '../../App';

const data: ListItem[] = Array.from({length: 50}, (_, i) => ({
  id: `item-${i}`,
  title: `List Item ${i + 1}`,
  subtitle: `This is a subtitle for item ${i + 1}`,
  type: i % 3 === 0 ? 'Featured' : 'Regular',
}));

interface ListsScreenProps {
  onItemPress: (item: ListItem) => void;
}

const ListsScreen: React.FC<ListsScreenProps> = ({onItemPress}) => {
  const renderItem = ({item}: {item: ListItem}) => (
    <TouchableOpacity style={styles.listItem} onPress={() => onItemPress(item)}>
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{item.id.slice(-2)}</Text>
      </View>
      <View style={styles.itemContent}>
        <View style={styles.itemHeader}>
          <Text style={styles.itemTitle}>{item.title}</Text>
          {item.type === 'Featured' && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>★</Text>
            </View>
          )}
        </View>
        <Text style={styles.itemSubtitle}>{item.subtitle}</Text>
      </View>
      <Text style={styles.arrow}>›</Text>
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Lists & ScrollViews</Text>
        <Text style={styles.headerSubtitle}>Test interaction tracking</Text>
      </View>
      <FlatList
        data={data}
        renderItem={renderItem}
        keyExtractor={item => item.id}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
        contentContainerStyle={styles.listContent}
      />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
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
  listContent: {
    paddingBottom: 20,
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 15,
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 15,
  },
  avatarText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
  itemContent: {
    flex: 1,
  },
  itemHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  itemTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#333',
  },
  badge: {
    backgroundColor: '#FFD700',
    borderRadius: 10,
    paddingHorizontal: 8,
    paddingVertical: 2,
    marginLeft: 8,
  },
  badgeText: {
    fontSize: 12,
    color: '#fff',
  },
  itemSubtitle: {
    fontSize: 14,
    color: '#666',
  },
  arrow: {
    fontSize: 24,
    color: '#ccc',
    marginLeft: 10,
  },
  separator: {
    height: 1,
    backgroundColor: '#f0f0f0',
  },
});

export default ListsScreen;
