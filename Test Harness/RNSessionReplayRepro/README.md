# RNSessionReplayRepro

React Native (0.88, New Architecture / Fabric) app for reproducing NR-652282: the Levi's app
(`newrelic-react-native-agent` 1.9.5, iOS agent 7.7.11) doesn't render properly in iOS Session
Replay.

The screens copy the shapes in the ticket's screenshots: a shop home with category chips, a
product carousel and product rows; a product page with an image carousel, thumbnails, price,
color swatches, "You may also like", a buy bar and a tab bar; and the code snippet attached to
the ticket (`Ticket code snippet →` on the home screen). Navigation uses
`@react-navigation/native-stack`, which is backed by `UINavigationController` through
react-native-screens.

## Setup

```sh
npm install
cp nr-config.example.ts nr-config.ts     # add an app token with Mobile Session Replay enabled
./scripts/build-local-agent.sh           # builds the agent from this repo (simulator only)
cd ios && pod install && cd ..
npx react-native run-ios
```

`ios/Podfile` points the `NewRelicAgent` pod at `ios/LocalNewRelicAgent`, so the app runs the
agent in this working tree. Run `./scripts/build-local-agent.sh` again after changing agent
code. To compare against the published agent, run `NR_PUBLISHED_AGENT=1 pod install`.

## Viewing a replay locally

The agent writes every rrweb frame to the app's `Documents/SessionReplayFrames` before
uploading it. These scripts collect those frames and play them back with rrweb's `Replayer`
in headless Chrome, so you don't need the New Relic UI:

```sh
# 1. While driving the app, copy frames out of the simulator.
./scripts/collect-frames.sh <simulator-udid> /tmp/frames

# 2. Render the replay at given offsets (seconds from the first event, or epoch ms).
node scripts/render-replay.mjs /tmp/frames /tmp/render 10,25.5,1795050210784

# 3. Optional: put simulator screenshots named <label>_<epochMs>.png next to the replay.
node scripts/compare.mjs /tmp/render /tmp/compare /tmp/shots/*.png
```

## Reproducing NR-652282

1. Open a product, open a "You may also like" product, then go back.
2. Render the replay around each navigation.

With iOS agent 7.7.11, the replay goes blank about a second after every push or pop and stays
blank until the next periodic full snapshot (every 15 s). During the transition UIKit hosts the
incoming screen in a `UIParallaxTransitionCardView`, then moves it to
`UIViewControllerWrapperView`. The screen keeps its replay node id, so the incremental diff
used to send only an attribute update for it while removing the transition container. In the
player, that removal takes the screen's whole subtree with it.

## UI permutations

`UI permutations →` at the bottom of the shop home screen opens one screen per case in
`src/permutations.tsx`. Each case targets one part of the agent's capture code, and the note at
the top of each screen says what to do and what the code predicts:

1. Text inside a `TouchableOpacity` link, toggling `disabled` (opacity changes in place)
2. Nested `<Text>` with mixed styles (`TextHelper` reads attributes at index 0 only)
3. Content that fades in from opacity 0, plus a "Load more" that fades in new rows
4. A loading skeleton swapped for content, and a remount under a new key with no visual change
5. Text updated in place every second, including a length change under `numberOfLines={1}`
6. A 200-row `FlatList` with `removeClippedSubviews`, with nested horizontal carousels
7. A bundled font (`BebasNeue-Regular.ttf`, SIL OFL, in `ios/RNSessionReplayRepro/Fonts`), an
   unbundled font name, an iOS-only system font, and `adjustsFontSizeToFit`
8. A `Navigation.showOverlay` toast (separate window), `Navigation.showModal`, and RN `<Modal>`
   in `pageSheet` and `fullScreen`
9. Rotated and scaled badges, and a carousel that slides with a native-driver `translateX`
10. `NewRelicMask` / `NewRelicUnmask` alone and nested both ways, plus testID targets
    (`snippet-link`, `mask-by-testid`, `mask-by-testid-view`) for custom masking rules. Switch
    the app's masking mode in the New Relic UI to try Default and each Custom toggle.

## Customer product page

`Customer PDP (ScrollViewport) →` on the shop home screen opens `src/customerPdp.tsx`, the
Levi's product page structure from their code shown on the NR-652282 call:
`ProductDisplayScreen > ScreenWrapper > ProductDisplayPage > PdpProvider > ProductSizeProvider >
ScrollViewport > MainContent`, with `OutOfStockRecommendations`, `GlobalError` and
`BottomButtons` next to the scroll view. `ScrollViewport` and `useViewport` are kept as written;
the other components have only their names and props from the screenshots.

- `ScrollViewport` replaces its context value on every scroll end, so every `useViewport`
  consumer re-renders: the hero's "Tap to zoom" chip and the "Complete the look" labels fade
  in, and the `visible: N%` captions change in place.
- `onScroll` (`scrollEventThrottle={16}`) fades the header title in and updates the
  `scroll depth` caption on every scroll event.
- The header search bar is added after an async `loadPdpScreen`, the product replaces a
  skeleton after 1.2 s, and the maintenance banner appears after 0.9 s.
- `Size guide` opens a `pageSheet` modal and sets `accessibilityElementsHidden` on the screen;
  the rating link scrolls to the reviews with `scrollTo`; `Simulate network error` shows the
  global error banner for 3 s; "Complete the look" tiles push another product page
  (the beanie shows the out-of-stock strip).
