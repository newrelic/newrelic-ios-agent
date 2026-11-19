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
