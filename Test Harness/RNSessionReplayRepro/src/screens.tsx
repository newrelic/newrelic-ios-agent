import React, { useState } from 'react';
import {
  Dimensions,
  FlatList,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Navigation, NavigationProps } from 'react-native-navigation';
import { RectButton } from 'react-native-gesture-handler';
import { NewRelicMask, NewRelicUnmask } from 'newrelic-react-native-agent';
import { CATEGORIES, PRODUCTS, Product } from './data';
import { Header, RemoteImage, TicketSnippet } from './components';
import { HeartIcon } from './icons';

export const SCREENS = {
  Home: 'repro.Home',
  Product: 'repro.Product',
  Snippet: 'repro.Snippet',
  Placeholder: 'repro.Placeholder',
};

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const push = (componentId: string, name: string, passProps: object = {}) =>
  Navigation.push(componentId, { component: { name, passProps } });

export function HomeScreen({ componentId }: NavigationProps) {
  const [category, setCategory] = useState(CATEGORIES[1]);
  return (
    <SafeAreaView style={styles.screen}>
      <Header title="Shop" />
      <ScrollView testID="home-scroll">
        <View style={styles.chips}>
          {CATEGORIES.map(c => (
            <Pressable
              key={c}
              testID={`chip-${c}`}
              onPress={() => setCategory(c)}
              style={[styles.chip, c === category && styles.chipActive]}>
              <Text style={[styles.chipText, c === category && styles.chipTextActive]}>{c}</Text>
            </Pressable>
          ))}
        </View>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Trending in {category}</Text>
          <Text style={styles.link}>See all</Text>
        </View>
        <FlatList
          horizontal
          data={PRODUCTS}
          keyExtractor={p => p.id}
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.carousel}
          renderItem={({ item }) => (
            <Pressable
              testID={`card-${item.id}`}
              onPress={() => push(componentId, SCREENS.Product, { productId: item.id })}
              style={styles.card}>
              <RemoteImage uri={item.images[0]} style={styles.cardImage} />
              <Text style={styles.cardName} numberOfLines={2}>{item.name}</Text>
              <Text style={styles.cardPrice}>{item.price}</Text>
            </Pressable>
          )}
        />
        {PRODUCTS.map(p => (
          <Pressable
            key={p.id}
            testID={`row-${p.id}`}
            onPress={() => push(componentId, SCREENS.Product, { productId: p.id })}
            style={styles.row}>
            <RemoteImage uri={p.images[0]} style={styles.rowImage} />
            <View style={styles.rowText}>
              <Text style={styles.rowName}>{p.name}</Text>
              <Text style={styles.rowPrice}>{p.price}</Text>
            </View>
          </Pressable>
        ))}
        <Pressable testID="open-snippet" onPress={() => push(componentId, SCREENS.Snippet)} style={styles.row}>
          <Text style={styles.rowName}>Ticket code snippet →</Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

export function ProductScreen({ componentId, productId }: NavigationProps & { productId: string }) {
  const product = PRODUCTS.find(p => p.id === productId) as Product;
  const [imageIndex, setImageIndex] = useState(0);
  const [swatch, setSwatch] = useState(0);
  const [favorite, setFavorite] = useState(false);
  const others = PRODUCTS.filter(p => p.id !== product.id);

  return (
    <SafeAreaView style={styles.screen}>
      <Header title={product.name} onBack={() => Navigation.pop(componentId)} />
      <ScrollView testID="pdp-scroll" contentContainerStyle={styles.pdpContent}>
        {/* Product photos aren't sensitive: unmask them when the account masks all images
            (Custom masking mode only; the Default mode masks everything regardless). */}
        <NewRelicUnmask>
          <FlatList
            horizontal
            pagingEnabled
            data={product.images}
            keyExtractor={(uri, i) => `${uri}-${i}`}
            showsHorizontalScrollIndicator={false}
            onMomentumScrollEnd={e =>
              setImageIndex(Math.round(e.nativeEvent.contentOffset.x / SCREEN_WIDTH))
            }
            renderItem={({ item }) => <RemoteImage uri={item} style={styles.hero} />}
          />
        </NewRelicUnmask>
        <Text style={styles.pdpName}>{product.name}</Text>
        <View style={styles.thumbs}>
          {product.images.map((uri, i) => (
            <View key={uri} style={[styles.thumbFrame, i === imageIndex && styles.thumbFrameActive]}>
              <RemoteImage uri={uri} style={styles.thumb} />
            </View>
          ))}
        </View>
        <View style={styles.priceRow}>
          <Text style={styles.price}>{product.price}</Text>
          {product.listPrice ? <Text style={styles.listPrice}>{product.listPrice}</Text> : null}
        </View>
        <Text style={styles.colorLabel}>
          <Text style={styles.colorLabelBold}>Color: </Text>Regular Grey
        </Text>
        <View style={styles.swatches}>
          {product.swatches.map((color, i) => (
            <Pressable
              key={color}
              testID={`swatch-${i}`}
              onPress={() => setSwatch(i)}
              style={[styles.swatchRing, i === swatch && styles.swatchRingActive]}>
              <View style={[styles.swatch, { backgroundColor: color }]} />
            </Pressable>
          ))}
        </View>
        {/* Personal data stays masked even when the account unmasks text. */}
        <NewRelicMask>
          <View style={styles.zipRow}>
            <Text style={styles.zipLabel}>Deliver to</Text>
            <TextInput testID="pdp-zip" style={styles.zipInput} defaultValue="94105" />
          </View>
        </NewRelicMask>
        <Text style={styles.sectionTitle}>You may also like</Text>
        <View style={styles.related}>
          {others.map(p => (
            <Pressable
              key={p.id}
              testID={`related-${p.id}`}
              onPress={() => push(componentId, SCREENS.Product, { productId: p.id })}
              style={styles.relatedCard}>
              <RemoteImage uri={p.images[0]} style={styles.relatedImage} />
              <Text style={styles.relatedName} numberOfLines={1}>{p.name}</Text>
            </Pressable>
          ))}
        </View>
      </ScrollView>
      <View style={styles.buyBar}>
        <TouchableOpacity
          testID="pdp-favorite"
          accessibilityRole="button"
          onPress={() => setFavorite(f => !f)}
          style={styles.heart}>
          <HeartIcon filled={favorite} color={favorite ? '#C8102E' : '#111111'} />
        </TouchableOpacity>
        <RectButton testID="pdp-cta" style={styles.cta}>
          <Text style={styles.ctaText}>{product.outOfStock ? 'Notify Me If In Stock' : 'Add to Bag'}</Text>
        </RectButton>
      </View>
    </SafeAreaView>
  );
}

export function SnippetScreen({ componentId }: NavigationProps) {
  return (
    <SafeAreaView style={styles.screen}>
      <Header title="Ticket snippet" onBack={() => Navigation.pop(componentId)} />
      <TicketSnippet automationId="snippet-link" title="Snippet link" style={styles.snippetLink} />
    </SafeAreaView>
  );
}

export function PlaceholderScreen({ title }: NavigationProps & { title: string }) {
  return (
    <SafeAreaView style={styles.screen}>
      <Header title={title} />
      <Text style={styles.placeholder}>{title}</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#FFFFFF' },
  chips: { flexDirection: 'row', paddingHorizontal: 12, paddingVertical: 12 },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    marginRight: 8,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#111111',
  },
  chipActive: { backgroundColor: '#111111' },
  chipText: { fontSize: 13, color: '#111111' },
  chipTextActive: { color: '#FFFFFF' },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 12 },
  sectionTitle: { fontSize: 16, fontWeight: '700', color: '#111111', paddingHorizontal: 12, marginVertical: 8 },
  link: { fontSize: 13, color: '#C8102E', marginTop: 10 },
  carousel: { paddingHorizontal: 8 },
  card: { width: 140, marginHorizontal: 4 },
  cardImage: { width: 140, height: 180, backgroundColor: '#EEEEEE' },
  cardName: { fontSize: 12, marginTop: 6, color: '#111111' },
  cardPrice: { fontSize: 12, fontWeight: '600', marginTop: 2, color: '#111111' },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D0D0D0',
  },
  rowImage: { width: 56, height: 56, backgroundColor: '#EEEEEE' },
  rowText: { marginLeft: 12, flex: 1 },
  rowName: { fontSize: 14, color: '#111111' },
  rowPrice: { fontSize: 13, color: '#555555', marginTop: 2 },
  pdpContent: { paddingBottom: 24 },
  hero: { width: SCREEN_WIDTH, height: SCREEN_WIDTH * 0.75, backgroundColor: '#EEEEEE' },
  pdpName: { textAlign: 'center', fontSize: 13, marginTop: 12, color: '#111111' },
  thumbs: { flexDirection: 'row', paddingHorizontal: 12, marginTop: 12 },
  thumbFrame: { padding: 2, marginRight: 8, borderWidth: 1, borderColor: 'transparent' },
  thumbFrameActive: { borderColor: '#111111' },
  thumb: { width: 72, height: 72, backgroundColor: '#EEEEEE' },
  priceRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    paddingHorizontal: 12,
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#D0D0D0',
  },
  price: { fontSize: 18, color: '#111111' },
  listPrice: { fontSize: 14, color: '#777777', marginLeft: 12, textDecorationLine: 'line-through' },
  colorLabel: { paddingHorizontal: 12, marginTop: 24, fontSize: 14, color: '#111111' },
  colorLabelBold: { fontWeight: '700' },
  swatches: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 8, marginTop: 12 },
  swatchRing: { padding: 3, margin: 4, borderRadius: 22, borderWidth: 2, borderColor: 'transparent' },
  swatchRingActive: { borderColor: '#111111' },
  swatch: { width: 34, height: 34, borderRadius: 17, borderWidth: StyleSheet.hairlineWidth, borderColor: '#BBBBBB' },
  zipRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, marginVertical: 12 },
  zipLabel: { fontSize: 14, color: '#111111', marginRight: 8 },
  zipInput: { flex: 1, height: 36, paddingHorizontal: 8, borderWidth: 1, borderColor: '#888888', borderRadius: 4 },
  related: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 8 },
  relatedCard: { width: (SCREEN_WIDTH - 32) / 3, margin: 4 },
  relatedImage: { width: '100%', height: 120, backgroundColor: '#EEEEEE' },
  relatedName: { fontSize: 11, marginTop: 4, color: '#111111' },
  buyBar: {
    flexDirection: 'row',
    padding: 12,
    backgroundColor: '#FFFFFF',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#D0D0D0',
  },
  heart: {
    width: 48,
    height: 48,
    borderWidth: 1,
    borderColor: '#111111',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cta: {
    flex: 1,
    height: 48,
    marginLeft: 12,
    backgroundColor: '#0E1B3D',
    alignItems: 'center',
    justifyContent: 'center',
  },
  ctaText: { color: '#FFFFFF', fontSize: 15, fontWeight: '600' },
  snippetLink: { height: 44, marginVertical: 8, backgroundColor: '#1F2A55', borderRadius: 4 },
  placeholder: { margin: 24, fontSize: 18, color: '#555555' },
});
