/**
 * Repro app for NR-652282: the Levi's React Native app doesn't render properly in iOS
 * Session Replay (newrelic-react-native-agent 1.9.5, iOS agent 7.7.11).
 *
 * Matches their stack: React Native's old architecture, react-native-navigation (native
 * stacks inside native bottom tabs), react-native-svg icons, react-native-gesture-handler.
 *
 * @format
 */

import { LogBox, Platform } from 'react-native';
import { Navigation } from 'react-native-navigation';
import { gestureHandlerRootHOC } from 'react-native-gesture-handler';
import NewRelic from 'newrelic-react-native-agent';
import { HomeScreen, PlaceholderScreen, ProductScreen, SCREENS, SnippetScreen } from './src/screens';
import { NR_CONFIG } from './nr-config';

// Dev warnings would otherwise draw over the screens under test.
LogBox.ignoreAllLogs();

const token = Platform.OS === 'ios' ? NR_CONFIG.iosToken : NR_CONFIG.androidToken;
if (token) {
  NewRelic.startAgent(token, {
    collectorAddress: NR_CONFIG.collectorAddress,
    crashCollectorAddress: NR_CONFIG.crashCollectorAddress,
    logLevel: NewRelic.LogLevel.DEBUG,
  });
}

Navigation.registerComponent(SCREENS.Home, () => gestureHandlerRootHOC(HomeScreen));
Navigation.registerComponent(SCREENS.Product, () => gestureHandlerRootHOC(ProductScreen));
Navigation.registerComponent(SCREENS.Snippet, () => gestureHandlerRootHOC(SnippetScreen));
Navigation.registerComponent(SCREENS.Placeholder, () => gestureHandlerRootHOC(PlaceholderScreen));

const TABS = [
  { id: 'discover', title: 'Discover', icon: require('./src/assets/tab-discover.png') },
  { id: 'shop', title: 'Shop', icon: require('./src/assets/tab-shop.png') },
  { id: 'favorites', title: 'Favorites', icon: require('./src/assets/tab-favorites.png') },
  { id: 'bag', title: 'Bag', icon: require('./src/assets/tab-bag.png') },
  { id: 'account', title: 'Account', icon: require('./src/assets/tab-account.png') },
];

Navigation.setDefaultOptions({
  topBar: { visible: false },
  bottomTab: { selectedTextColor: '#C8102E', selectedIconColor: '#C8102E' },
});

Navigation.events().registerAppLaunchedListener(() => {
  Navigation.setRoot({
    root: {
      bottomTabs: {
        options: { bottomTabs: { currentTabIndex: 1 } },
        children: TABS.map(tab => ({
          stack: {
            id: `stack-${tab.id}`,
            children: [
              tab.id === 'shop'
                ? { component: { name: SCREENS.Home } }
                : { component: { name: SCREENS.Placeholder, passProps: { title: tab.title } } },
            ],
            options: { bottomTab: { text: tab.title, icon: tab.icon } },
          },
        })),
      },
    },
  });
});
