import React from 'react';
import {
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  ViewStyle,
} from 'react-native';
import { BackIcon, SearchIcon } from './icons';

// The component from the code snippet attached to NR-652282, kept as written:
// a self-closing TouchableOpacity with testID / accessibility props, nested in
// ScrollView > View > View next to a Text.
export function TicketSnippet(props: {
  automationId: string;
  disabled?: boolean;
  style?: ViewStyle;
  title: string;
}) {
  return (
    <ScrollView>
      <View>
        <View>
          <Text> Title </Text>
          <TouchableOpacity
            testID={props.automationId}
            disabled={props.disabled}
            accessibilityRole="link"
            style={[props.style]}
            accessibilityState={{
              disabled: props.disabled,
            }}
            accessibilityLabel={props.title}
          />
        </View>
        <View>
          <Text> Description </Text>
        </View>
      </View>
    </ScrollView>
  );
}

export function Header(props: { title: string; onBack?: () => void }) {
  return (
    <View style={styles.header}>
      <Pressable testID="header-back" onPress={props.onBack} style={styles.headerIcon}>
        {props.onBack ? <BackIcon /> : null}
      </Pressable>
      <Text style={styles.headerTitle} numberOfLines={1}>
        {props.title}
      </Text>
      <View style={styles.headerIcon}>
        <SearchIcon />
      </View>
    </View>
  );
}

export function RemoteImage(props: { uri: string; style: any; testID?: string }) {
  return (
    <Image
      testID={props.testID}
      source={{ uri: props.uri }}
      style={props.style}
      resizeMode="cover"
    />
  );
}

const styles = StyleSheet.create({
  header: {
    height: 52,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    backgroundColor: '#FFFFFF',
    // Bottom-only hairline, the usual RN header separator.
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D0D0D0',
  },
  headerIcon: { width: 32, height: 32, alignItems: 'center', justifyContent: 'center' },
  headerTitle: { flex: 1, textAlign: 'center', fontSize: 16, fontWeight: '600', color: '#111111' },
});
