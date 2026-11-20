// The Levi's product page structure, rebuilt from their code shown on the NR-652282 call:
// ProductDisplayScreen > ScreenWrapper > ProductDisplayPage > PdpProvider > ProductSizeProvider >
// ScrollViewport > MainContent, with OutOfStockRecommendations, GlobalError and BottomButtons
// next to the scroll view. ScrollViewport and useViewport are kept as written; the rest only
// has the screenshots' names and props, so its contents are filler shaped like their app.
//
// What this exercises in the replay:
// - ScrollViewport replaces its context value on every scroll end and on layout, so every
//   useViewport consumer re-renders and changes text and opacity in place.
// - onScroll (scrollEventThrottle 16) drives the header title's opacity and a scroll-depth
//   readout while the page scrolls.
// - loadPdpScreen adds the header search bar after an async load, the product arrives after a
//   skeleton, and the maintenance banner appears late.
// - The size guide modal sets accessibilityElementsHidden on the whole screen.

import React, {
  Component,
  ComponentType,
  PropsWithChildren,
  RefObject,
  createContext,
  forwardRef,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import {
  Animated,
  Dimensions,
  FlatList,
  LayoutChangeEvent,
  Modal,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Pressable,
  SafeAreaView,
  ScrollView,
  ScrollViewProps,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Navigation, NavigationProps } from 'react-native-navigation';
import { RectButton } from 'react-native-gesture-handler';
import { PRODUCTS, Product } from './data';
import { RemoteImage } from './components';
import { BackIcon, HeartIcon, SearchIcon } from './icons';
import { SCREENS, push } from './screens';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const SIZES = ['28', '29', '30', '31', '32', '33', '34', '36'];
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

// ---- ScrollViewport (src/components/ui/ScrollViewport.tsx) ----

interface IViewportContext {
  contentOffset?: { x: number; y: number };
  layoutMeasurement?: { height: number; width: number };
  scrollViewNode?: number;
}

const ViewportContext = createContext<IViewportContext>({});

type Layout = { x: number; y: number; width: number; height: number };

interface IViewportData {
  layout?: Layout;
  percentVisible: { x: number; y: number };
}

const visibleFraction = (start: number, length: number, viewStart: number, viewLength: number) => {
  if (length <= 0) {
    return 0;
  }
  const visible = Math.min(start + length, viewStart + viewLength) - Math.max(start, viewStart);
  return Math.max(0, Math.min(1, visible / length));
};

export const useViewport = (ref: RefObject<Component | null>) => {
  const scrollviewContext = useContext(ViewportContext);
  const [layout, setLayout] = useState<Layout>();
  const [viewportData, setViewportData] = useState<IViewportData>({ percentVisible: { x: 0, y: 0 } });

  useEffect(() => {
    const node = ref.current as unknown as View | null;
    if (!node || !scrollviewContext.scrollViewNode) {
      return;
    }
    node.measureLayout(
      scrollviewContext.scrollViewNode,
      (x, y, width, height) => setLayout({ x, y, width, height }),
      () => {},
    );
  }, [ref, scrollviewContext]);

  useEffect(() => {
    const { contentOffset, layoutMeasurement } = scrollviewContext;
    if (!layout || !contentOffset || !layoutMeasurement) {
      return;
    }
    const percentXVisibile = visibleFraction(layout.x, layout.width, contentOffset.x, layoutMeasurement.width);
    const percentYVisible = visibleFraction(layout.y, layout.height, contentOffset.y, layoutMeasurement.height);
    setViewportData(current => ({
      ...current,
      layout,
      percentVisible: { x: percentXVisibile, y: percentYVisible },
    }));
  }, [scrollviewContext, layout]);

  return viewportData;
};

const ScrollViewport = forwardRef<ScrollView, PropsWithChildren<ScrollViewProps>>(
  ({ children, onMomentumScrollEnd, onScrollEndDrag, ...props }, forwardedRef) => {
    const [viewportContext, setViewportContext] = useState({} as IViewportContext);

    const handleScrollEnd = (evt: NativeSyntheticEvent<NativeScrollEvent>) => {
      const { contentOffset } = evt.nativeEvent;
      setViewportContext(current => ({ ...current, contentOffset }));
      onMomentumScrollEnd?.(evt);
      onScrollEndDrag?.(evt);
    };

    const handleLayout = (evt: LayoutChangeEvent) => {
      // this DOES exist on nativeEvent, promise
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      const { target } = evt.nativeEvent;
      const { height, width } = evt.nativeEvent.layout;
      setViewportContext(current => ({
        ...current,
        contentOffset: {
          y: 0,
          x: 0,
        },
        layoutMeasurement: {
          height,
          width,
        },
        scrollViewNode: target ?? 0,
      }));
    };

    return (
      <ViewportContext.Provider value={viewportContext}>
        <ScrollView
          ref={forwardedRef}
          {...props}
          onLayout={handleLayout}
          onMomentumScrollEnd={handleScrollEnd}
          onScrollEndDrag={handleScrollEnd}>
          {children}
        </ScrollView>
      </ViewportContext.Provider>
    );
  },
);

ScrollViewport.displayName = 'ScrollViewport';

// ---- Screen style HOC and wrapper ----

type HeaderOptions = {
  showSearchAndScanBar?: boolean;
  showScannerSearchBarHeaderTitle?: boolean;
  rightHeaderElements?: 'scan' | 'none';
};

type ScreenStyleProps = {
  updateScreenStyle: (options: HeaderOptions) => void;
  updateScreenTitleStyle: (style: { opacity: number }) => void;
};

function withScreenStyle<P extends NavigationProps & { title?: string }>(
  Screen: ComponentType<P & ScreenStyleProps>,
  config: { theme: 'light' | 'dark' },
) {
  return (props: P) => {
    const [options, setOptions] = useState<HeaderOptions>({});
    const [titleStyle, setTitleStyle] = useState({ opacity: 0 });
    const updateScreenStyle = useCallback((o: HeaderOptions) => setOptions(cur => ({ ...cur, ...o })), []);
    const updateScreenTitleStyle = useCallback((s: { opacity: number }) => setTitleStyle(s), []);
    return (
      <SafeAreaView style={[styles.screen, config.theme === 'dark' && styles.screenDark]}>
        <View style={styles.header}>
          <Pressable testID="header-back" onPress={() => Navigation.pop(props.componentId)} style={styles.headerIcon}>
            <BackIcon />
          </Pressable>
          <Text testID="pdp-header-title" style={[styles.headerTitle, titleStyle]} numberOfLines={1}>
            {props.title}
          </Text>
          <View style={styles.headerIcon}>
            {options.rightHeaderElements === 'scan' ? <Text style={styles.scanText}>Scan</Text> : null}
          </View>
        </View>
        {options.showSearchAndScanBar ? (
          <View style={styles.searchBar}>
            <SearchIcon />
            <TextInput style={styles.searchInput} placeholder="Search or scan a barcode" />
          </View>
        ) : null}
        <Screen {...props} updateScreenStyle={updateScreenStyle} updateScreenTitleStyle={updateScreenTitleStyle} />
      </SafeAreaView>
    );
  };
}

function ScreenWrapper(props: PropsWithChildren<{
  testID: string;
  accessibilityElementsHidden: boolean;
  importantForAccessibility: 'auto' | 'no-hide-descendants';
}>) {
  const { children, ...rest } = props;
  return (
    <View style={styles.flex} {...rest}>
      {children}
    </View>
  );
}

function MaintenanceBanner() {
  const [message, setMessage] = useState<string>();
  useEffect(() => {
    const t = setTimeout(() => setMessage('Scheduled maintenance tonight, 1–3 AM ET'), 900);
    return () => clearTimeout(t);
  }, []);
  return message ? (
    <View testID="maintenance-banner" style={styles.maintenance}>
      <Text style={styles.maintenanceText}>{message}</Text>
    </View>
  ) : null;
}

// ---- Providers ----

type PdpContextValue = {
  componentId: string;
  product?: Product;
  scrollRef: RefObject<ScrollView>;
  isStoreMode: boolean;
  isScrollToRating: boolean;
  scrollDepth: number;
  error?: string;
  setError: (error?: string) => void;
  openSizeGuide: () => void;
};

const PdpContext = createContext({} as PdpContextValue);
const usePdp = () => useContext(PdpContext);

function PdpProvider(props: PropsWithChildren<{
  componentId: string;
  isStoreMode: boolean;
  productId: string;
  scrollRef: RefObject<ScrollView>;
  isScrollToRating: boolean;
  scrollDepth: number;
  openSizeGuide: () => void;
}>) {
  const [product, setProduct] = useState<Product>();
  const [error, setError] = useState<string>();
  useEffect(() => {
    setProduct(undefined);
    const t = setTimeout(() => setProduct(PRODUCTS.find(p => p.id === props.productId)), 1200);
    return () => clearTimeout(t);
  }, [props.productId]);
  return (
    <PdpContext.Provider
      value={{
        componentId: props.componentId,
        product,
        scrollRef: props.scrollRef,
        isStoreMode: props.isStoreMode,
        isScrollToRating: props.isScrollToRating,
        scrollDepth: props.scrollDepth,
        error,
        setError,
        openSizeGuide: props.openSizeGuide,
      }}>
      {props.children}
    </PdpContext.Provider>
  );
}

const ProductSizeContext = createContext({
  selectedSize: undefined as string | undefined,
  setSelectedSize: (_: string) => {},
});

function ProductSizeProvider(props: PropsWithChildren<{}>) {
  const [selectedSize, setSelectedSize] = useState<string>();
  return (
    <ProductSizeContext.Provider value={{ selectedSize, setSelectedSize }}>
      {props.children}
    </ProductSizeContext.Provider>
  );
}

// ---- Page contents ----

// Shows hotspot labels once the hero is mostly on screen (their ProductOverlay.tsx uses
// useViewport).
function ProductOverlay(props: { percentVisible: number; index: number; count: number }) {
  const fade = useRef(new Animated.Value(0)).current;
  const shown = props.percentVisible > 0.6;
  useEffect(() => {
    Animated.timing(fade, { toValue: shown ? 1 : 0, duration: 300, useNativeDriver: true }).start();
  }, [fade, shown]);
  return (
    <View style={styles.overlay} pointerEvents="none">
      <Text testID="hero-index" style={styles.overlayChip}>
        {props.index + 1} / {props.count}
      </Text>
      <Animated.Text style={[styles.overlayChip, { opacity: fade }]}>Tap to zoom</Animated.Text>
    </View>
  );
}

function Hero({ product }: { product: Product }) {
  const ref = useRef<View>(null);
  const { percentVisible } = useViewport(ref as unknown as RefObject<Component>);
  const [index, setIndex] = useState(0);
  return (
    <View ref={ref}>
      <FlatList
        horizontal
        pagingEnabled
        data={product.images}
        keyExtractor={(uri, i) => `${uri}-${i}`}
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={e => setIndex(Math.round(e.nativeEvent.contentOffset.x / SCREEN_WIDTH))}
        renderItem={({ item }) => <RemoteImage uri={item} style={styles.hero} />}
      />
      <ProductOverlay percentVisible={percentVisible.y} index={index} count={product.images.length} />
      <Text style={styles.viewportCaption}>hero visible: {Math.round(percentVisible.y * 100)}%</Text>
    </View>
  );
}

function SizePicker() {
  const { selectedSize, setSelectedSize } = useContext(ProductSizeContext);
  const { openSizeGuide } = usePdp();
  return (
    <View style={styles.block}>
      <View style={styles.rowBetween}>
        <Text testID="pdp-size-label" style={styles.label}>
          Waist: <Text style={styles.bold}>{selectedSize ?? 'Select'}</Text>
        </Text>
        <Text testID="pdp-size-guide" style={styles.link} onPress={openSizeGuide}>
          Size guide
        </Text>
      </View>
      <View style={styles.sizes}>
        {SIZES.map(size => (
          <Pressable
            key={size}
            testID={`pdp-size-${size}`}
            onPress={() => setSelectedSize(size)}
            style={[styles.size, size === selectedSize && styles.sizeActive]}>
            <Text style={[styles.sizeText, size === selectedSize && styles.sizeTextActive]}>{size}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

// Their CompleteTheLookOverlay.tsx also uses useViewport; here the tile labels fade in once
// the section is half visible.
function CompleteTheLook({ product }: { product: Product }) {
  const ref = useRef<View>(null);
  const { percentVisible } = useViewport(ref as unknown as RefObject<Component>);
  const { componentId } = usePdp();
  const others = PRODUCTS.filter(p => p.id !== product.id);
  const shown = percentVisible.y > 0.5;
  return (
    <View ref={ref} style={styles.block}>
      <Text style={styles.sectionTitle}>Complete the look</Text>
      <Text testID="ctl-visible" style={styles.viewportCaption}>
        section visible: {Math.round(percentVisible.y * 100)}%
      </Text>
      <View style={styles.tiles}>
        {others.map(p => (
          <Pressable
            key={p.id}
            testID={`ctl-${p.id}`}
            onPress={() => push(componentId, SCREENS.CustomerPdp, { productId: p.id, title: p.name })}
            style={styles.tile}>
            <RemoteImage uri={p.images[0]} style={styles.tileImage} />
            <Text style={[styles.tileLabel, { opacity: shown ? 1 : 0 }]} numberOfLines={1}>
              {p.name}
            </Text>
            <Text style={[styles.tilePrice, { opacity: shown ? 1 : 0 }]}>{p.price}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function Details() {
  const [open, setOpen] = useState(false);
  return (
    <View style={styles.block}>
      <Pressable testID="pdp-details" onPress={() => setOpen(o => !o)} style={styles.rowBetween}>
        <Text style={styles.sectionTitle}>Details</Text>
        <Text style={styles.label}>{open ? '−' : '+'}</Text>
      </Pressable>
      {open ? (
        <Text style={styles.body}>
          The original blue jean since 1873. Sits at waist, regular through the thigh, straight leg.
          99% cotton, 1% elastane. Machine wash cold.
        </Text>
      ) : null}
    </View>
  );
}

function Reviews(props: { onLayoutY: (y: number) => void }) {
  return (
    <View testID="pdp-reviews" style={styles.block} onLayout={e => props.onLayoutY(e.nativeEvent.layout.y)}>
      <Text style={styles.sectionTitle}>Reviews</Text>
      {['Fits true to size.', 'Great everyday jeans.', 'Color faded a little after washing.'].map((r, i) => (
        <View key={r} style={styles.review}>
          <Text style={styles.stars}>{'★★★★★'.slice(0, 5 - (i % 2))}</Text>
          <Text style={styles.body}>{r}</Text>
        </View>
      ))}
    </View>
  );
}

function MainContent() {
  const { product, scrollRef, isScrollToRating, setError } = usePdp();
  const reviewsY = useRef(0);
  const scrollToRating = useCallback(
    () => scrollRef.current?.scrollTo({ y: reviewsY.current, animated: true }),
    [scrollRef],
  );
  useEffect(() => {
    if (product && isScrollToRating) {
      setTimeout(scrollToRating, 300);
    }
  }, [product, isScrollToRating, scrollToRating]);

  if (!product) {
    return (
      <View testID="pdp-skeleton">
        <View style={[styles.hero, styles.skeleton]} />
        <View style={[styles.skeletonLine, { width: '70%' }]} />
        <View style={[styles.skeletonLine, { width: '30%' }]} />
      </View>
    );
  }
  return (
    <View>
      <Hero product={product} />
      <View style={styles.block}>
        <Text testID="pdp-name" style={styles.name}>{product.name}</Text>
        <Text style={styles.price}>
          {product.price} {product.listPrice ? <Text style={styles.strike}>{product.listPrice}</Text> : null}
        </Text>
        <Text testID="pdp-rating" style={styles.link} onPress={scrollToRating}>
          ★★★★☆ 4.6 (1,203 reviews)
        </Text>
      </View>
      <SizePicker />
      <Details />
      <CompleteTheLook product={product} />
      <Reviews onLayoutY={y => (reviewsY.current = y)} />
      <Text testID="pdp-simulate-error" style={[styles.link, styles.block]} onPress={() => setError('Something went wrong. Try again.')}>
        Simulate network error
      </Text>
    </View>
  );
}

function OutOfStockRecommendations() {
  const { product } = usePdp();
  if (!product?.outOfStock) {
    return null;
  }
  return (
    <View testID="oos-recommendations" style={styles.oos}>
      <Text style={styles.oosText}>Out of stock. Similar styles are available below.</Text>
    </View>
  );
}

function GlobalError() {
  const { error, setError } = usePdp();
  useEffect(() => {
    if (!error) {
      return;
    }
    const t = setTimeout(() => setError(undefined), 3000);
    return () => clearTimeout(t);
  }, [error, setError]);
  return error ? (
    <View testID="global-error" style={styles.globalError}>
      <Text style={styles.globalErrorText}>{error}</Text>
    </View>
  ) : null;
}

const GlobalErrorWithAnalytics = () => {
  const { error } = usePdp();
  useEffect(() => {
    if (error) {
      console.log('[analytics] pdp_error', error);
    }
  }, [error]);
  return <GlobalError />;
};

function BottomButtons(props: { isDiscover: boolean }) {
  const { product, scrollDepth } = usePdp();
  const { selectedSize } = useContext(ProductSizeContext);
  const [favorite, setFavorite] = useState(false);
  const cta = product?.outOfStock ? 'Notify Me If In Stock' : selectedSize ? 'Add to Bag' : 'Select a Size';
  return (
    <View style={styles.buyBar}>
      {/* Their handleScrollDepth only reports analytics; it's shown here so the replay has text
          that changes on every scroll event. */}
      <Text testID="pdp-scroll-depth" style={styles.viewportCaption}>
        scroll depth: {Math.round(scrollDepth * 100)}%{props.isDiscover ? ' (discover)' : ''}
      </Text>
      <View style={styles.buyRow}>
        <TouchableOpacity testID="pdp-favorite" onPress={() => setFavorite(f => !f)} style={styles.heart}>
          <HeartIcon filled={favorite} color={favorite ? '#C8102E' : '#111111'} />
        </TouchableOpacity>
        <RectButton testID="pdp-cta" style={styles.cta}>
          <Text testID="pdp-cta-text" style={styles.ctaText}>{cta}</Text>
        </RectButton>
      </View>
    </View>
  );
}

// ---- ProductDisplayPage (src/components/productDisplay/index.tsx) ----

type ProductDisplayPageProps = {
  componentId: string;
  productId: string;
  isStoreMode: boolean;
  recommendedStore?: string;
  selectedShippingOption?: string;
  updateScreenTitleStyle: (style: { opacity: number }) => void;
  isScrollToRating: boolean;
  searchTerm?: string;
  isDiscover: boolean;
  isLsa?: boolean;
  openSizeGuide: () => void;
};

const ProductDisplayPage = ({
  componentId,
  isStoreMode,
  productId,
  updateScreenTitleStyle,
  isScrollToRating,
  isDiscover,
  isLsa = false,
  openSizeGuide,
}: ProductDisplayPageProps) => {
  const scrollRef = useRef<ScrollView>(null);
  const [scrollDepth, setScrollDepth] = useState(0);

  // Fade the header title in as the product name scrolls under it.
  const handleScroll = useCallback(
    (e: NativeSyntheticEvent<NativeScrollEvent>) => {
      const y = e.nativeEvent.contentOffset.y;
      updateScreenTitleStyle({ opacity: Math.max(0, Math.min(1, (y - SCREEN_WIDTH * 0.75) / 60)) });
    },
    [updateScreenTitleStyle],
  );
  const handleScrollDepth = useCallback((e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const { contentOffset, layoutMeasurement, contentSize } = e.nativeEvent;
    const depth = Math.min(1, (contentOffset.y + layoutMeasurement.height) / contentSize.height);
    setScrollDepth(current => Math.max(current, depth));
  }, []);

  const onScroll = useCallback(
    (e: NativeSyntheticEvent<NativeScrollEvent>) => {
      handleScroll(e);
      handleScrollDepth(e);
    },
    [handleScroll, handleScrollDepth],
  );

  return (
    <PdpProvider
      componentId={componentId}
      isStoreMode={!!isStoreMode}
      productId={productId}
      scrollRef={scrollRef}
      isScrollToRating={isScrollToRating}
      scrollDepth={scrollDepth}
      openSizeGuide={openSizeGuide}>
      <ProductSizeProvider>
        <ScrollViewport
          ref={scrollRef}
          onScroll={onScroll}
          scrollEventThrottle={16}
          testID="PDPScrollContainer">
          <MainContent />
        </ScrollViewport>
        <OutOfStockRecommendations />
        {!isLsa && <GlobalErrorWithAnalytics />}
        <BottomButtons isDiscover={isDiscover} />
        {isLsa && <GlobalError />}
      </ProductSizeProvider>
    </PdpProvider>
  );
};

// ---- ProductDisplayScreen (src/screens/ProductDisplayScreen.tsx) ----

type ProductDisplayScreenProps = NavigationProps & {
  productId?: string;
  title?: string;
  isStoreMode?: boolean;
  isScrollToRating?: boolean;
  isDiscover?: boolean;
};

const ProductDisplayScreen = ({
  componentId,
  productId = 'jeans',
  isStoreMode = false,
  isScrollToRating = false,
  isDiscover = false,
  updateScreenStyle,
  updateScreenTitleStyle,
}: ProductDisplayScreenProps & ScreenStyleProps) => {
  const [isModalVisible, setIsModalVisible] = useState(false);
  const storeMode = isStoreMode;

  const loadPdpScreen = useCallback(async () => {
    await delay(600);
    if (!storeMode) {
      updateScreenStyle({
        showSearchAndScanBar: true,
        showScannerSearchBarHeaderTitle: false,
        rightHeaderElements: 'scan',
      });
    }
  }, [storeMode, updateScreenStyle]);

  useEffect(() => {
    loadPdpScreen();
  }, [loadPdpScreen]);

  return (
    <ScreenWrapper
      testID="PDPScreen"
      accessibilityElementsHidden={isModalVisible}
      importantForAccessibility={isModalVisible ? 'no-hide-descendants' : 'auto'}>
      <MaintenanceBanner />
      <ProductDisplayPage
        componentId={componentId}
        productId={productId}
        isStoreMode={isStoreMode}
        updateScreenTitleStyle={updateScreenTitleStyle}
        isScrollToRating={isScrollToRating}
        isDiscover={isDiscover}
        openSizeGuide={() => setIsModalVisible(true)}
      />
      <Modal visible={isModalVisible} animationType="slide" presentationStyle="pageSheet" onRequestClose={() => setIsModalVisible(false)}>
        <SafeAreaView style={styles.screen}>
          <View style={styles.block}>
            <Text style={styles.name}>Size guide</Text>
            {SIZES.map(s => (
              <Text key={s} style={styles.body}>
                Waist {s}: {Math.round(Number(s) * 2.54)} cm
              </Text>
            ))}
            <Text testID="size-guide-close" style={[styles.link, styles.block]} onPress={() => setIsModalVisible(false)}>
              Close
            </Text>
          </View>
        </SafeAreaView>
      </Modal>
    </ScreenWrapper>
  );
};

export const CustomerPdpScreen = withScreenStyle(ProductDisplayScreen, { theme: 'light' });

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: { flex: 1, backgroundColor: '#FFFFFF' },
  screenDark: { backgroundColor: '#111111' },
  header: {
    height: 52,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D0D0D0',
  },
  headerIcon: { width: 40, height: 32, alignItems: 'center', justifyContent: 'center' },
  headerTitle: { flex: 1, textAlign: 'center', fontSize: 16, fontWeight: '600', color: '#111111' },
  scanText: { fontSize: 13, color: '#C8102E', fontWeight: '600' },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 12,
    marginVertical: 8,
    paddingHorizontal: 10,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#F1F1F1',
  },
  searchInput: { flex: 1, marginLeft: 8, fontSize: 14 },
  maintenance: { backgroundColor: '#FFF4CE', padding: 8 },
  maintenanceText: { fontSize: 12, color: '#5C4400', textAlign: 'center' },
  hero: { width: SCREEN_WIDTH, height: SCREEN_WIDTH * 0.75, backgroundColor: '#EEEEEE' },
  skeleton: { backgroundColor: '#E4E4E4' },
  skeletonLine: { height: 16, marginHorizontal: 12, marginTop: 12, backgroundColor: '#E4E4E4' },
  overlay: { position: 'absolute', top: 8, left: 8, right: 8, flexDirection: 'row', justifyContent: 'space-between' },
  overlayChip: {
    fontSize: 12,
    color: '#FFFFFF',
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    overflow: 'hidden',
    borderRadius: 10,
  },
  viewportCaption: { fontSize: 11, color: '#777777', paddingHorizontal: 12, paddingVertical: 4 },
  block: { paddingHorizontal: 12, paddingVertical: 12 },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  name: { fontSize: 18, fontWeight: '700', color: '#111111' },
  price: { fontSize: 16, color: '#111111', marginTop: 6 },
  strike: { fontSize: 14, color: '#777777', textDecorationLine: 'line-through' },
  link: { fontSize: 13, color: '#C8102E', marginTop: 8 },
  label: { fontSize: 14, color: '#111111' },
  bold: { fontWeight: '700' },
  body: { fontSize: 14, color: '#333333', marginTop: 6 },
  sizes: { flexDirection: 'row', flexWrap: 'wrap', marginTop: 8 },
  size: { width: 52, height: 40, margin: 4, borderWidth: 1, borderColor: '#BBBBBB', alignItems: 'center', justifyContent: 'center' },
  sizeActive: { borderColor: '#111111', backgroundColor: '#111111' },
  sizeText: { fontSize: 14, color: '#111111' },
  sizeTextActive: { color: '#FFFFFF' },
  sectionTitle: { fontSize: 16, fontWeight: '700', color: '#111111' },
  tiles: { flexDirection: 'row', marginTop: 8 },
  tile: { width: (SCREEN_WIDTH - 40) / 3, marginRight: 8 },
  tileImage: { width: '100%', height: 140, backgroundColor: '#EEEEEE' },
  tileLabel: { fontSize: 11, color: '#111111', marginTop: 4 },
  tilePrice: { fontSize: 11, fontWeight: '600', color: '#111111' },
  review: { paddingVertical: 8, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#D0D0D0' },
  stars: { color: '#C8102E', fontSize: 13 },
  oos: { backgroundColor: '#F4F4F4', padding: 10 },
  oosText: { fontSize: 13, color: '#111111' },
  globalError: { position: 'absolute', top: 0, left: 0, right: 0, backgroundColor: '#C8102E', padding: 12 },
  globalErrorText: { color: '#FFFFFF', fontSize: 14, textAlign: 'center' },
  buyBar: { backgroundColor: '#FFFFFF', borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#D0D0D0' },
  buyRow: { flexDirection: 'row', paddingHorizontal: 12, paddingBottom: 12 },
  heart: { width: 48, height: 48, borderWidth: 1, borderColor: '#111111', alignItems: 'center', justifyContent: 'center' },
  cta: { flex: 1, height: 48, marginLeft: 12, backgroundColor: '#0E1B3D', alignItems: 'center', justifyContent: 'center' },
  ctaText: { color: '#FFFFFF', fontSize: 15, fontWeight: '600' },
});
