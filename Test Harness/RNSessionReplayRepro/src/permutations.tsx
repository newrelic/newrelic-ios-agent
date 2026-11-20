// UI permutations for NR-652282. Each screen targets one part of the iOS agent's capture
// code; the note at the top of each screen says what to do and what the code predicts.

import React, { useEffect, useRef, useState } from 'react';
import {
  Animated,
  Button,
  Easing,
  FlatList,
  Modal,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Navigation, NavigationProps, OptionsModalPresentationStyle } from 'react-native-navigation';
import { NewRelicMask, NewRelicUnmask } from 'newrelic-react-native-agent';
import { PRODUCTS } from './data';
import { Header, RemoteImage } from './components';
import { SCREENS, push } from './screens';

const PERMUTATIONS = [
  { screen: SCREENS.PermLink, title: '1. Text inside a link, toggling disabled' },
  { screen: SCREENS.PermNestedText, title: '2. Nested <Text> with mixed styles' },
  { screen: SCREENS.PermFadeIn, title: '3. Content that fades in' },
  { screen: SCREENS.PermSkeleton, title: '4. Loading skeleton swapped for content' },
  { screen: SCREENS.PermLiveText, title: '5. Text updated in place' },
  { screen: SCREENS.PermClippedList, title: '6. Lists that detach views' },
  { screen: SCREENS.PermFonts, title: '7. Custom fonts and auto-shrinking text' },
  { screen: SCREENS.PermOverlays, title: '8. Overlays, toasts and modals' },
  { screen: SCREENS.PermTransforms, title: '9. Transforms' },
  { screen: SCREENS.PermMasking, title: '10. Masking' },
  { screen: SCREENS.PermReviewFixes, title: '11. PR #1001 review fixes' },
  { screen: SCREENS.PermNavSnapshots, title: '12. Navigation full snapshots' },
];

function PermutationScreen(props: {
  componentId: string;
  title: string;
  note: string;
  scroll?: boolean;
  children: React.ReactNode;
}) {
  const note = <Text style={styles.note}>{props.note}</Text>;
  return (
    <SafeAreaView style={styles.screen}>
      <Header title={props.title} onBack={() => Navigation.pop(props.componentId)} />
      {props.scroll === false ? (
        <View style={styles.flex}>
          {note}
          {props.children}
        </View>
      ) : (
        <ScrollView contentContainerStyle={styles.content}>
          {note}
          {props.children}
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

function Section(props: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{props.title}</Text>
      {props.children}
    </View>
  );
}

export function PermutationsScreen({ componentId }: NavigationProps) {
  return (
    <SafeAreaView style={styles.screen}>
      <Header title="UI permutations" onBack={() => Navigation.pop(componentId)} />
      <ScrollView testID="perm-list">
        {PERMUTATIONS.map((p, i) => (
          <Pressable
            key={p.screen}
            testID={`perm-${i + 1}`}
            onPress={() => push(componentId, p.screen)}
            style={styles.row}>
            <Text style={styles.rowText}>{p.title}</Text>
          </Pressable>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

// 1. Text inside a touchable, plus an in-place opacity change.
export function LinkScreen({ componentId }: NavigationProps) {
  const [disabled, setDisabled] = useState(false);
  return (
    <PermutationScreen
      componentId={componentId}
      title="Link + disabled"
      note="Toggle disabled (opacity 1 → 0.4 in place). Also press and hold the link: TouchableOpacity animates opacity to 0.2 while pressed.">
      <TouchableOpacity
        testID="snippet-link"
        disabled={disabled}
        accessibilityRole="link"
        accessibilityState={{ disabled }}
        accessibilityLabel="Shop the sale"
        style={[styles.link, disabled && styles.linkDisabled]}>
        <Text style={styles.linkText}>Shop the sale</Text>
      </TouchableOpacity>
      <Button testID="toggle-disabled" title="Toggle disabled" onPress={() => setDisabled(d => !d)} />
      <Text style={styles.caption}>disabled: {String(disabled)}</Text>
    </PermutationScreen>
  );
}

// 2. Attributed strings built from nested <Text>. TextHelper reads attributes at index 0 only.
export function NestedTextScreen({ componentId }: NavigationProps) {
  return (
    <PermutationScreen
      componentId={componentId}
      title="Nested text"
      note="Expect each line to take the first span's style: line 2 all bold, the strike-through on nothing, the link not blue.">
      <Section title="Regular, then bold span">
        <Text style={styles.body}>
          Color: <Text style={styles.bold}>Regular Grey</Text>
        </Text>
      </Section>
      <Section title="Bold, then regular red span">
        <Text style={[styles.body, styles.bold]}>
          Bold first, <Text style={styles.regularRed}>then red regular</Text>
        </Text>
      </Section>
      <Section title="Price with struck-through list price">
        <Text style={styles.body}>
          $18.98 <Text style={styles.strike}>$25.00</Text>
        </Text>
      </Section>
      <Section title="Inline link">
        <Text style={styles.body}>
          By continuing you agree to the <Text style={styles.inlineLink}>Terms</Text>.
        </Text>
      </Section>
      <Section title="Mixed sizes">
        <Text style={styles.body}>
          Small <Text style={styles.big}>BIG</Text> small
        </Text>
      </Section>
    </PermutationScreen>
  );
}

function FadeIn(props: { children: React.ReactNode; duration?: number }) {
  const fade = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(fade, { toValue: 1, duration: props.duration ?? 600, useNativeDriver: true }).start();
  }, [fade, props.duration]);
  return <Animated.View style={{ opacity: fade }}>{props.children}</Animated.View>;
}

// 3. Views that mount at alpha 0. ViewDetails skips alpha == 0, so a later diff has to add them.
export function FadeInScreen({ componentId }: NavigationProps) {
  const [generation, setGeneration] = useState(0);
  const [rows, setRows] = useState(0);
  return (
    <PermutationScreen
      componentId={componentId}
      title="Fade in"
      note="The banner fades in on mount. If the incremental add is missed, it stays missing in the replay until the next full snapshot (every 15 s). Load more fades in new rows.">
      <FadeIn key={generation}>
        <View style={styles.banner}>
          <Text style={styles.bannerText}>Free shipping on orders over $50</Text>
        </View>
      </FadeIn>
      <Button testID="fade-replay" title="Remount banner (fade again)" onPress={() => setGeneration(g => g + 1)} />
      {Array.from({ length: rows }, (_, i) => (
        <FadeIn key={i}>
          <View style={styles.row}>
            <Text style={styles.rowText}>Loaded row {i + 1}</Text>
          </View>
        </FadeIn>
      ))}
      <Button testID="fade-load-more" title="Load more" onPress={() => setRows(r => r + 3)} />
    </PermutationScreen>
  );
}

function ProductSummary() {
  return (
    <View>
      <Text style={styles.title}>Backpatch Beanie</Text>
      <Text style={styles.body}>$18.98</Text>
    </View>
  );
}

// 4. Remount at the same position: the remove/add path in IncrementalDiffGenerator.
export function SkeletonScreen({ componentId }: NavigationProps) {
  const [loaded, setLoaded] = useState(false);
  const [remountKey, setRemountKey] = useState(0);
  useEffect(() => {
    if (loaded) {
      return;
    }
    const t = setTimeout(() => setLoaded(true), 1500);
    return () => clearTimeout(t);
  }, [loaded]);
  return (
    <PermutationScreen
      componentId={componentId}
      title="Skeleton → content"
      note="The skeleton is swapped for content after 1.5 s. The second section remounts identical content under a new key, so the view tree changes with no visual change.">
      <Section title="Skeleton swap">
        {loaded ? (
          <View key="content">
            <ProductSummary />
          </View>
        ) : (
          <View key="skeleton" style={styles.skeleton} />
        )}
        <Button testID="skeleton-reload" title="Show skeleton again" onPress={() => setLoaded(false)} />
      </Section>
      <Section title="Remount under a new key">
        <View key={`${PRODUCTS[0].id}-${remountKey}`}>
          <ProductSummary />
        </View>
        <Button testID="skeleton-remount" title="Remount (same content)" onPress={() => setRemountKey(k => k + 1)} />
      </Section>
    </PermutationScreen>
  );
}

// 5. Text changed in place on an existing RCTTextView.
export function LiveTextScreen({ componentId }: NavigationProps) {
  const [n, setN] = useState(0);
  useEffect(() => {
    const i = setInterval(() => setN(x => x + 1), 1000);
    return () => clearInterval(i);
  }, []);
  return (
    <PermutationScreen
      componentId={componentId}
      title="Live text"
      note="Both lines change every second. The replay should follow, and the second line's frame should track its length under numberOfLines={1}.">
      <Section title="Counter">
        <Text testID="live-count" style={styles.body}>Items in bag: {n}</Text>
      </Section>
      <Section title="Short / long, numberOfLines={1}">
        <Text testID="live-title" style={styles.body} numberOfLines={1}>
          {n % 2 ? 'Short' : 'A much longer title that has to be truncated on one line'}
        </Text>
      </Section>
      <Section title="Inside a fixed-width box">
        <View style={styles.fixedBox}>
          <Text style={styles.body} numberOfLines={1}>
            {n % 2 ? 'Short' : 'A much longer title that has to be truncated on one line'}
          </Text>
        </View>
      </Section>
    </PermutationScreen>
  );
}

type ClippedRow = { key: string; carousel: boolean };
const CLIPPED_ROWS: ClippedRow[] = Array.from({ length: 200 }, (_, i) => ({
  key: `Row ${i}`,
  carousel: i > 0 && i % 25 === 0,
}));
const CAROUSEL_IMAGES = PRODUCTS.flatMap(p => p.images);

// 6. removeClippedSubviews detaches off-screen rows and reattaches them while scrolling.
export function ClippedListScreen({ componentId }: NavigationProps) {
  return (
    <PermutationScreen
      componentId={componentId}
      title="Clipped list"
      scroll={false}
      note="Scroll fast down, then back up: rows must not be blank after scrolling back. Every 25th row is a horizontal carousel that also clips.">
      <FlatList
        testID="clipped-list"
        data={CLIPPED_ROWS}
        removeClippedSubviews
        initialNumToRender={8}
        windowSize={3}
        keyExtractor={x => x.key}
        renderItem={({ item }) =>
          item.carousel ? (
            <View>
              <Text style={styles.clippedRow}>{item.key} (carousel)</Text>
              <FlatList
                horizontal
                removeClippedSubviews
                data={CAROUSEL_IMAGES}
                keyExtractor={(uri, i) => `${uri}-${i}`}
                showsHorizontalScrollIndicator={false}
                renderItem={({ item: uri, index }) => (
                  <View style={styles.carouselCard}>
                    <RemoteImage uri={uri} style={styles.carouselImage} />
                    <Text style={styles.caption}>Image {index}</Text>
                  </View>
                )}
              />
            </View>
          ) : (
            <Text style={styles.clippedRow}>{item.key}</Text>
          )
        }
      />
    </PermutationScreen>
  );
}

// 7. Fonts the replay browser doesn't have, and adjustsFontSizeToFit.
export function FontsScreen({ componentId }: NavigationProps) {
  return (
    <PermutationScreen
      componentId={componentId}
      title="Fonts"
      note="Labels are drawn with overflow: hidden at the device frame width. A wider fallback font gets clipped or wraps out of view. With adjustsFontSizeToFit the agent records the declared size, not the shrunk one. The gray boxes show each label's frame.">
      <Section title="Bundled font (BebasNeue-Regular.ttf)">
        <View style={styles.frame}>
          <Text style={styles.bebas}>Notify Me If In Stock</Text>
        </View>
      </Section>
      <Section title="Customer font name, not bundled (Levi-Sans-Bold)">
        <View style={styles.frame}>
          <Text style={styles.leviSans}>Notify Me If In Stock</Text>
        </View>
      </Section>
      <Section title="iOS system font (AvenirNext-Heavy)">
        <View style={styles.frame}>
          <Text style={styles.avenir}>Notify Me If In Stock</Text>
        </View>
      </Section>
      <Section title="adjustsFontSizeToFit, width 120">
        <View style={styles.frame}>
          <Text style={styles.shrink} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.5}>
            501® Original Fit Men's Jeans
          </Text>
        </View>
      </Section>
      <Section title="Bundled font + adjustsFontSizeToFit, width 120">
        <View style={styles.frame}>
          <Text
            style={[styles.shrink, styles.bebas]}
            numberOfLines={1}
            adjustsFontSizeToFit
            minimumFontScale={0.5}>
            501® Original Fit Men's Jeans
          </Text>
        </View>
      </Section>
    </PermutationScreen>
  );
}

// Shown with Navigation.showOverlay, which puts it in its own UIWindow.
export function ToastOverlay({ componentId, message }: NavigationProps & { message: string }) {
  useEffect(() => {
    const t = setTimeout(() => Navigation.dismissOverlay(componentId), 4000);
    return () => clearTimeout(t);
  }, [componentId]);
  return (
    <View style={styles.toastRoot} pointerEvents="box-none">
      <View style={styles.toast}>
        <Text style={styles.toastText}>{message}</Text>
      </View>
    </View>
  );
}

type RNModalStyle = 'pageSheet' | 'fullScreen';

// 8. Overlays (separate window) versus modals (same window).
export function OverlaysScreen({ componentId }: NavigationProps) {
  const [rnModal, setRnModal] = useState<RNModalStyle | null>(null);
  const showNavModal = (style: OptionsModalPresentationStyle) =>
    Navigation.showModal({
      stack: {
        children: [{ component: { name: SCREENS.Snippet, passProps: { modal: true } } }],
        options: { modalPresentationStyle: style },
      },
    });
  return (
    <PermutationScreen
      componentId={componentId}
      title="Overlays & modals"
      note="NRMASessionReplay records only the key window, so the showOverlay toast should be missing from the replay. Modals in the same window should be captured.">
      <Section title="react-native-navigation overlay">
        <Button
          testID="show-toast"
          title="Show toast (showOverlay, 4 s)"
          onPress={() =>
            Navigation.showOverlay({
              component: {
                name: SCREENS.Toast,
                passProps: { message: 'Added to bag' },
                options: {
                  overlay: { interceptTouchOutside: false },
                  layout: { componentBackgroundColor: 'transparent' },
                },
              },
            })
          }
        />
      </Section>
      <Section title="react-native-navigation modal">
        <Button testID="nav-modal-page" title="showModal (pageSheet)" onPress={() => showNavModal(OptionsModalPresentationStyle.pageSheet)} />
        <Button testID="nav-modal-full" title="showModal (fullScreen)" onPress={() => showNavModal(OptionsModalPresentationStyle.fullScreen)} />
      </Section>
      <Section title="React Native <Modal>">
        <Button testID="rn-modal-page" title="<Modal> pageSheet" onPress={() => setRnModal('pageSheet')} />
        <Button testID="rn-modal-full" title="<Modal> fullScreen" onPress={() => setRnModal('fullScreen')} />
      </Section>
      <Modal
        visible={rnModal !== null}
        animationType="slide"
        presentationStyle={rnModal ?? 'pageSheet'}
        onRequestClose={() => setRnModal(null)}>
        <SafeAreaView style={styles.screen}>
          <View style={styles.content}>
            <Text style={styles.title}>RN Modal ({rnModal})</Text>
            <Text style={styles.body}>This text is inside a React Native Modal.</Text>
            <View style={styles.banner}>
              <Text style={styles.bannerText}>Free shipping on orders over $50</Text>
            </View>
            <Button testID="rn-modal-close" title="Close" onPress={() => setRnModal(null)} />
          </View>
        </SafeAreaView>
      </Modal>
    </PermutationScreen>
  );
}

// 9. The recorder keeps only the converted frame, no transform.
export function TransformsScreen({ componentId }: NavigationProps) {
  const slide = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(slide, { toValue: -200, duration: 1500, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(slide, { toValue: 0, duration: 1500, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [slide]);
  return (
    <PermutationScreen
      componentId={componentId}
      title="Transforms"
      note="Expect the rotated badge to show unrotated in its bounding box, and the sliding carousel to show a position but no animation.">
      <Section title="rotate: -8deg">
        <View style={styles.badgeRow}>
          <View style={[styles.badge, styles.rotated]}>
            <Text style={styles.badgeText}>SALE</Text>
          </View>
        </View>
      </Section>
      <Section title="scale: 1.5">
        <View style={styles.badgeRow}>
          <View style={[styles.badge, styles.scaled]}>
            <Text style={styles.badgeText}>NEW</Text>
          </View>
        </View>
      </Section>
      <Section title="translateX (native driver loop)">
        <View style={styles.slideClip}>
          <Animated.View style={[styles.slideTrack, { transform: [{ translateX: slide }] }]}>
            {PRODUCTS.map(p => (
              <View key={p.id} style={styles.carouselCard}>
                <RemoteImage uri={p.images[0]} style={styles.carouselImage} />
                <Text style={styles.caption} numberOfLines={1}>{p.name}</Text>
              </View>
            ))}
          </Animated.View>
        </View>
      </Section>
    </PermutationScreen>
  );
}

// 10. Masking components and testID-based rules. Pair with the account's masking settings.
export function MaskingScreen({ componentId }: NavigationProps) {
  return (
    <PermutationScreen
      componentId={componentId}
      title="Masking"
      note="Switch the app's replay setting to Default (full masking), then Custom with each toggle. For a custom rule, mask or unmask by accessibility identifier: snippet-link, mask-by-testid.">
      <Section title="No wrapper">
        <Text style={styles.body}>Plain text, no mask wrapper</Text>
        <TextInput testID="mask-plain-input" style={styles.input} defaultValue="plain input 94105" />
        <RemoteImage uri={PRODUCTS[0].images[0]} style={styles.maskImage} />
      </Section>
      <Section title="<NewRelicMask>">
        <NewRelicMask>
          <Text style={styles.body}>Inside Mask</Text>
          <TextInput style={styles.input} defaultValue="masked input 94105" />
        </NewRelicMask>
      </Section>
      <Section title="<NewRelicUnmask>">
        <NewRelicUnmask>
          <Text style={styles.body}>Inside Unmask</Text>
          <TextInput style={styles.input} defaultValue="unmasked input 94105" />
          <RemoteImage uri={PRODUCTS[1].images[0]} style={styles.maskImage} />
        </NewRelicUnmask>
      </Section>
      <Section title="<NewRelicUnmask> > <NewRelicMask>">
        <NewRelicUnmask>
          <Text style={styles.body}>Outer: Unmask</Text>
          <NewRelicMask>
            <Text style={styles.body}>Inner: Mask (expect masked)</Text>
          </NewRelicMask>
        </NewRelicUnmask>
      </Section>
      <Section title="<NewRelicMask> > <NewRelicUnmask>">
        <NewRelicMask>
          <Text style={styles.body}>Outer: Mask</Text>
          <NewRelicUnmask>
            <Text style={styles.body}>Inner: Unmask (expect unmasked)</Text>
          </NewRelicUnmask>
        </NewRelicMask>
      </Section>
      <Section title="testID targets for custom rules">
        <TouchableOpacity testID="snippet-link" accessibilityRole="link" style={styles.link}>
          <Text style={styles.linkText}>Shop the sale (testID snippet-link)</Text>
        </TouchableOpacity>
        <Text testID="mask-by-testid" style={styles.body}>Text with testID mask-by-testid</Text>
        <View testID="mask-by-testid-view" style={styles.banner}>
          <Text style={styles.bannerText}>View with testID mask-by-testid-view</Text>
        </View>
      </Section>
    </PermutationScreen>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#FFFFFF' },
  flex: { flex: 1 },
  content: { padding: 12, paddingBottom: 32 },
  note: {
    fontSize: 12,
    color: '#555555',
    backgroundColor: '#F4F4F4',
    padding: 8,
    marginBottom: 12,
  },
  row: {
    padding: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D0D0D0',
  },
  rowText: { fontSize: 14, color: '#111111' },
  section: { marginBottom: 20 },
  sectionTitle: { fontSize: 12, fontWeight: '600', color: '#777777', marginBottom: 6 },
  title: { fontSize: 18, fontWeight: '700', color: '#111111' },
  body: { fontSize: 15, color: '#111111' },
  caption: { fontSize: 11, color: '#555555', marginTop: 4 },
  bold: { fontWeight: '700' },
  regularRed: { fontWeight: '400', color: '#C8102E' },
  strike: { textDecorationLine: 'line-through', color: '#777777' },
  inlineLink: { color: 'blue', textDecorationLine: 'underline' },
  big: { fontSize: 24 },
  link: {
    height: 44,
    marginVertical: 8,
    paddingHorizontal: 16,
    backgroundColor: '#1F2A55',
    borderRadius: 4,
    justifyContent: 'center',
  },
  linkDisabled: { opacity: 0.4 },
  linkText: { color: '#FFFFFF', fontSize: 15, fontWeight: '600' },
  banner: { backgroundColor: '#0E1B3D', padding: 12, marginVertical: 8 },
  bannerText: { color: '#FFFFFF', fontSize: 14 },
  skeleton: { height: 40, backgroundColor: '#EEEEEE' },
  fixedBox: { width: 160, borderWidth: 1, borderColor: '#D0D0D0', padding: 4 },
  clippedRow: {
    padding: 16,
    fontSize: 14,
    color: '#111111',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D0D0D0',
  },
  carouselCard: { width: 120, marginHorizontal: 4, marginBottom: 8 },
  carouselImage: { width: 120, height: 150, backgroundColor: '#EEEEEE' },
  frame: { alignSelf: 'flex-start', backgroundColor: '#EEEEEE' },
  bebas: { fontFamily: 'BebasNeue-Regular', fontSize: 16, color: '#111111' },
  leviSans: { fontFamily: 'Levi-Sans-Bold', fontSize: 16, color: '#111111' },
  avenir: { fontFamily: 'AvenirNext-Heavy', fontSize: 16, color: '#111111' },
  shrink: { width: 120, fontSize: 16, color: '#111111' },
  toastRoot: { flex: 1, justifyContent: 'flex-end', alignItems: 'center', paddingBottom: 120 },
  toast: { backgroundColor: '#111111', borderRadius: 20, paddingHorizontal: 20, paddingVertical: 10 },
  toastText: { color: '#FFFFFF', fontSize: 14 },
  badgeRow: { flexDirection: 'row', padding: 12 },
  badge: { backgroundColor: '#C8102E', padding: 6 },
  badgeText: { color: '#FFFFFF', fontWeight: '700' },
  rotated: { transform: [{ rotate: '-8deg' }] },
  scaled: { transform: [{ scale: 1.5 }] },
  slideClip: { overflow: 'hidden' },
  slideTrack: { flexDirection: 'row' },
  input: {
    height: 36,
    paddingHorizontal: 8,
    marginVertical: 6,
    borderWidth: 1,
    borderColor: '#888888',
    borderRadius: 4,
  },
  maskImage: { width: 80, height: 100, backgroundColor: '#EEEEEE', marginTop: 6 },
});
