// One screen with a case for each fix from the PR #1001 review that this app can show. It
// uses the old architecture like the Levi's app, so the two Fabric-only fixes (text padding
// read from the layout metrics, border bitmaps sent as stylesheet rules) don't apply here.

import React, { useEffect, useState } from 'react';
import { Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Navigation, NavigationProps } from 'react-native-navigation';
import { Header } from './components';
import { HeartIcon, SearchIcon } from './icons';

function Case(props: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.case}>
      <Text style={styles.caseTitle}>{props.title}</Text>
      {props.children}
    </View>
  );
}

export function ReviewFixesScreen({ componentId }: NavigationProps) {
  const [liked, setLiked] = useState(false);
  const [ticks, setTicks] = useState(0);
  // Redraws the hearts on their own, so the replay shows each new drawing.
  useEffect(() => {
    const timer = setInterval(() => setTicks(t => t + 1), 1500);
    return () => clearInterval(timer);
  }, []);

  return (
    <SafeAreaView style={styles.screen}>
      <Header title="Review fixes" onBack={() => Navigation.pop(componentId)} />
      <ScrollView testID="review-fixes" contentContainerStyle={styles.content}>
        <Case title="Padded text keeps its background and border">
          <View style={styles.row}>
            <Text style={styles.saleBadge}>SALE</Text>
            <Text style={styles.newBadge}>NEW</Text>
            <Text style={styles.outlinedBadge}>Limited edition</Text>
          </View>
        </Case>

        <Case title="RCTView borders">
          <View style={styles.rtl}>
            <View style={[styles.box, styles.startBorder]}>
              <Text style={styles.boxText}>borderStart in RTL: right edge</Text>
            </View>
          </View>
          <View style={[styles.box, styles.startBeatsLeft]}>
            <Text style={styles.boxText}>borderStartColor (blue) beats borderLeftColor (red)</Text>
          </View>
          <View style={[styles.box, styles.blockColor]}>
            <Text style={styles.boxText}>borderBlockColor: red top and bottom</Text>
          </View>
          <View style={[styles.box, styles.dashed]}>
            <Text style={styles.boxText}>borderStyle: dashed</Text>
          </View>
          <View style={styles.pill}>
            <Text style={styles.pillText}>radii scaled per corner</Text>
          </View>
        </Case>

        <Case title="SVG icons redraw">
          <View style={styles.row}>
            <Pressable testID="review-heart" onPress={() => setLiked(l => !l)} hitSlop={8}>
              <HeartIcon size={32} color="#C8102E" filled={liked} />
            </Pressable>
            <HeartIcon size={32} color="#111111" filled={ticks % 2 === 1} />
            <SearchIcon size={32} color={ticks % 3 === 0 ? '#0057B8' : '#111111'} />
            <Text style={styles.caption}>tap the red heart; the others change every 1.5 s ({ticks})</Text>
          </View>
        </Case>

        <Case title="Carousel inside a scrolling box">
          <ScrollView testID="review-outer" style={styles.outer} nestedScrollEnabled>
            <Text style={styles.caption}>Scroll this box: the carousel stays inside its edges.</Text>
            <ScrollView horizontal testID="review-carousel" style={styles.carousel}>
              {['#C8102E', '#0057B8', '#2E7D32', '#F2A900', '#6A1B9A'].map(color => (
                <View key={color} style={[styles.slide, { backgroundColor: color }]} />
              ))}
            </ScrollView>
            <View style={styles.filler} />
          </ScrollView>
        </Case>

        <Case title="Text field">
          <TextInput testID="review-input" style={styles.input} placeholder="Type here" placeholderTextColor="#888888" />
        </Case>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#FFFFFF' },
  content: { padding: 12, paddingBottom: 48 },
  case: { marginBottom: 18 },
  caseTitle: { fontSize: 12, fontWeight: '600', color: '#777777', marginBottom: 6 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap' },
  saleBadge: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    backgroundColor: '#C8102E',
    color: '#FFFFFF',
    fontWeight: '700',
    borderRadius: 10,
    overflow: 'hidden',
  },
  newBadge: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#111111',
    color: '#FFFFFF',
    fontSize: 12,
  },
  outlinedBadge: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderWidth: 2,
    borderColor: '#0057B8',
    color: '#0057B8',
  },
  rtl: { direction: 'rtl' },
  box: { height: 36, justifyContent: 'center', paddingHorizontal: 10, marginBottom: 8, backgroundColor: '#F4F4F4' },
  boxText: { fontSize: 12, color: '#111111' },
  startBorder: { borderStartWidth: 6, borderStartColor: '#C8102E' },
  startBeatsLeft: { borderLeftWidth: 6, borderLeftColor: '#C8102E', borderStartColor: '#0057B8' },
  blockColor: { borderWidth: 3, borderColor: '#111111', borderBlockColor: '#C8102E' },
  dashed: { borderWidth: 2, borderColor: '#111111', borderStyle: 'dashed' },
  pill: {
    height: 28,
    borderRadius: 28,
    borderTopLeftRadius: 0,
    backgroundColor: '#111111',
    justifyContent: 'center',
    paddingHorizontal: 14,
  },
  pillText: { fontSize: 12, color: '#FFFFFF' },
  caption: { fontSize: 11, color: '#555555', flexShrink: 1 },
  outer: { height: 150, borderWidth: 1, borderColor: '#D0D0D0' },
  carousel: { marginTop: 40 },
  slide: { width: 140, height: 90, marginRight: 8 },
  filler: { height: 260 },
  input: { height: 40, borderWidth: 1, borderColor: '#D0D0D0', paddingHorizontal: 10, fontSize: 15, color: '#111111' },
});
