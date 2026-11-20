// Navigation cases for the iOS agent's full snapshot after a UINavigationController push or pop
// (SessionReplayCapture.recordNavigationState, SessionReplayFrameProcessor's
// fullSnapshotAfterNavigation). Every React Native Navigation screen is an
// RNNComponentViewController, so before that change a push between them kept
// rootViewControllerId and got only incremental diffs.
//
// The agent captures a frame once a second. Each case notes which frames should come out as
// full snapshots (`type: 2` in Documents/SessionReplayFrames, see scripts/collect-frames.sh).

import React, { useEffect, useState } from 'react';
import { Dimensions, Modal, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Navigation, NavigationProps, Options } from 'react-native-navigation';
import { Header } from './components';
import { SCREENS } from './screens';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

// Long enough that at least two captures land while the transition coordinator is active.
const SLOW_MS = 2500;

type Mode = 'default' | 'slow' | 'instant';

const STEP_COLORS = ['#C8102E', '#0057B8', '#2E7D32', '#F2A900', '#6A1B9A', '#00838F'];

function animationsFor(mode: Mode): Options['animations'] {
  switch (mode) {
    case 'default':
      return undefined;
    case 'instant':
      // No transition coordinator: the first frame after the push is already settled.
      return { push: { enabled: false }, pop: { enabled: false } };
    case 'slow':
      return {
        push: {
          content: {
            enter: { translationX: { from: SCREEN_WIDTH, to: 0, duration: SLOW_MS } },
            exit: { translationX: { from: 0, to: -SCREEN_WIDTH / 3, duration: SLOW_MS } },
          },
        },
        pop: {
          content: {
            enter: { translationX: { from: -SCREEN_WIDTH / 3, to: 0, duration: SLOW_MS } },
            exit: { translationX: { from: 0, to: SCREEN_WIDTH, duration: SLOW_MS } },
          },
        },
      };
  }
}

type StepProps = { step: number; mode: Mode; launcherId: string; inModal?: boolean };

const pushStep = (componentId: string, props: StepProps) =>
  Navigation.push(componentId, {
    component: { name: SCREENS.PermNavStep, passProps: props, options: { animations: animationsFor(props.mode) } },
  });

function Case(props: { title: string; expect: string; children: React.ReactNode }) {
  return (
    <View style={styles.case}>
      <Text style={styles.caseTitle}>{props.title}</Text>
      <Text style={styles.expect}>{props.expect}</Text>
      {props.children}
    </View>
  );
}

function Action(props: { testID: string; title: string; onPress: () => void }) {
  return (
    <Pressable testID={props.testID} onPress={props.onPress} style={styles.action}>
      <Text style={styles.actionText}>{props.title}</Text>
    </Pressable>
  );
}

// Text that changes every second, so the frames between full snapshots carry incremental
// updates and a stale screen in the replay is easy to spot.
function Ticker(props: { label: string }) {
  const [ticks, setTicks] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => setTicks(t => t + 1), 1000);
    return () => clearInterval(timer);
  }, []);
  return (
    <Text style={styles.ticker}>
      {props.label} · {ticks}s
    </Text>
  );
}

export function NavigationSnapshotsScreen({ componentId }: NavigationProps) {
  const [rnModalVisible, setRnModalVisible] = useState(false);

  return (
    <SafeAreaView style={styles.screen}>
      <Header title="Navigation full snapshots" onBack={() => Navigation.pop(componentId)} />
      <ScrollView testID="nav-snapshots" contentContainerStyle={styles.content}>
        <Ticker label="launcher" />

        <Case
          title="A. Push a screen of the same class"
          expect="Default 0.35 s animation. One full snapshot: on the push's first frame if the animation has ended, else on the next one.">
          <Action testID="nav-push-default" title="Push step 1" onPress={() => pushStep(componentId, { step: 1, mode: 'default', launcherId: componentId })} />
        </Case>

        <Case
          title="B. Push with a 2.5 s animation"
          expect="Two or three frames land mid-transition: incremental only. One full snapshot on the first frame after the animation ends, then incremental again.">
          <Action testID="nav-push-slow" title="Slow push step 1" onPress={() => pushStep(componentId, { step: 1, mode: 'slow', launcherId: componentId })} />
        </Case>

        <Case
          title="C. Push without animation"
          expect="No transition coordinator, so the push's first frame is already settled and is the full snapshot.">
          <Action testID="nav-push-instant" title="Instant push step 1" onPress={() => pushStep(componentId, { step: 1, mode: 'instant', launcherId: componentId })} />
        </Case>

        <Case
          title="D. Interactive pop, held and cancelled"
          expect="On any pushed step: swipe from the left edge halfway, hold 2 s, drag back and let go. Frames during the hold: incremental. One full snapshot after letting go, of the same screen. Repeat and finish the swipe for a completed pop.">
          <Action testID="nav-push-gesture" title="Push step 1 to swipe on" onPress={() => pushStep(componentId, { step: 1, mode: 'default', launcherId: componentId })} />
        </Case>

        <Case
          title="E. Modal stack, then push inside it"
          expect="showModal changes the navigation controllers in the window (the modal's stack comes in, and a full-screen modal takes the tab's out): one full snapshot once it settles. Pushing inside the modal changes the modal stack's top id: another one. Dismissing: another.">
          <Action
            testID="nav-modal-stack"
            title="Show modal stack"
            onPress={() =>
              Navigation.showModal({
                stack: {
                  children: [
                    { component: { name: SCREENS.PermNavStep, passProps: { step: 1, mode: 'default', launcherId: componentId, inModal: true } } },
                  ],
                },
              })
            }
          />
        </Case>

        <Case
          title="F. Close an RN <Modal> and push in the same tap"
          expect="Opening the <Modal> changes rootViewControllerId (to RCTModalHostViewController) and takes the tab's stack out of the window in the same frame. Closing it and pushing changes both back at once. Each gives one full snapshot, not one plus a second on the next frame.">
          <Action testID="nav-rn-modal" title="Open RN <Modal>" onPress={() => setRnModalVisible(true)} />
        </Case>

        <Case
          title="G. Switch tabs"
          expect="Tap another tab, then Shop again. Each switch shows a different stack, so its top id replaces this one: one full snapshot per switch.">
          <Text style={styles.caption}>Use the tab bar below.</Text>
        </Case>
      </ScrollView>

      <Modal visible={rnModalVisible} animationType="none" presentationStyle="fullScreen" onRequestClose={() => setRnModalVisible(false)}>
        {/* SafeAreaView ignores padding on iOS, so the padding goes on an inner view. */}
        <SafeAreaView style={[styles.screen, styles.rnModal]}>
          <View style={styles.rnModalBody}>
            <Text style={styles.stepTitle}>RN {'<Modal>'}</Text>
            <Ticker label="rn modal" />
            <Action
              testID="nav-rn-modal-close-push"
              title="Close and push step 1"
              onPress={() => {
                setRnModalVisible(false);
                pushStep(componentId, { step: 1, mode: 'instant', launcherId: componentId });
              }}
            />
            <Action testID="nav-rn-modal-close" title="Close" onPress={() => setRnModalVisible(false)} />
          </View>
        </SafeAreaView>
      </Modal>
    </SafeAreaView>
  );
}

export function NavStepScreen({ componentId, step, mode, launcherId, inModal }: NavigationProps & StepProps) {
  const color = STEP_COLORS[(step - 1) % STEP_COLORS.length];
  const next = { step: step + 1, mode, launcherId, inModal };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: color }]}>
      <Header title={`Step ${step} (${mode})`} onBack={() => Navigation.pop(componentId)} />
      <View style={styles.stepBody}>
        <Text testID="nav-step-title" style={styles.stepTitle}>
          Step {step}
        </Text>
        <Ticker label={inModal ? 'modal stack' : 'tab stack'} />
        <Action testID="nav-step-push" title={`Push step ${step + 1} (${mode})`} onPress={() => pushStep(componentId, next)} />
        {mode !== 'default' ? (
          <Action testID="nav-step-push-default" title={`Push step ${step + 1} (default)`} onPress={() => pushStep(componentId, { ...next, mode: 'default' })} />
        ) : null}
        <Action testID="nav-step-pop" title="Pop" onPress={() => Navigation.pop(componentId)} />
        {inModal ? (
          <Action testID="nav-step-dismiss" title="Dismiss modal" onPress={() => Navigation.dismissModal(componentId)} />
        ) : (
          <Action testID="nav-step-pop-launcher" title="Pop to launcher" onPress={() => Navigation.popTo(launcherId)} />
        )}
        <Text style={styles.hint}>Swipe from the left edge to pop interactively (case D).</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#FFFFFF' },
  content: { padding: 12, paddingBottom: 48 },
  case: { marginBottom: 16, paddingBottom: 12, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#D0D0D0' },
  caseTitle: { fontSize: 14, fontWeight: '700', color: '#111111', marginBottom: 4 },
  expect: { fontSize: 12, color: '#555555', marginBottom: 8 },
  caption: { fontSize: 12, color: '#555555' },
  action: { alignSelf: 'flex-start', paddingHorizontal: 14, paddingVertical: 8, marginTop: 6, backgroundColor: '#111111', borderRadius: 6 },
  actionText: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  ticker: { fontSize: 13, color: '#111111', marginBottom: 12, fontVariant: ['tabular-nums'] },
  stepBody: { flex: 1, padding: 16, backgroundColor: 'rgba(255,255,255,0.85)', margin: 16, borderRadius: 12 },
  stepTitle: { fontSize: 40, fontWeight: '800', color: '#111111', marginBottom: 8 },
  hint: { fontSize: 12, color: '#555555', marginTop: 16 },
  rnModal: { backgroundColor: '#FFF4E5' },
  rnModalBody: { padding: 24 },
});
