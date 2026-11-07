# Word Crush Mania — iOS

Native Swift/SwiftUI implementation for iPhone and iPad, targeting iOS/iPadOS 17 or newer. Prepared from the private Android project `benjaminpaul00-cell/WordCrushMania`, reviewed at commit `27076bbb58cd44f566f988831a698226151bf108`.

**Status: implementation prepared; Apple build and runtime validation pending.** Repository: [benjaminpaul00-cell/wordcrushmania-ios](https://github.com/benjaminpaul00-cell/wordcrushmania-ios). See [validation status](Docs/VALIDATION.md) before treating this as a release.

## Open on a Mac

Install Xcode with an iOS simulator runtime and XcodeGen, then run:

```sh
brew install xcodegen
bash bootstrap.command
```

Select the `WordCrushMania` scheme and an iPhone or iPad simulator. For physical devices, choose your own Apple development team in Signing & Capabilities. `project.yml` is the authoritative Xcode project specification; the generated `.xcodeproj` is ignored.

The main app links Google Mobile Ads 13.12.0 and UMP 3.1.0 via Swift Package Manager. The independent `GameCore` package has no advertising dependency.

## Included

- Three target words per level, orthogonal swaps, forward/reverse horizontal or vertical matches, gravity, bounded cascades, special tiles, obstacles, verified hints and recovery shuffles.
- A versioned seeded iOS generator covering levels 1–10,000, ten themes and grid sizes 6–9. Seeds and layouts are intentionally not identical to Kotlin Random.
- English themed vocabulary extracted from the existing dictionary: 809 entries across ten lists, with words shared by some themes.
- A 30-second active-play clock, pause/resume, saved remaining time, lives, transactional progression, inventory, daily rewards, challenges and achievements.
- Home, level journey, gameplay, results, booster vault, daily rewards, statistics and settings. Wide iPad windows use a board and side panel; compact windows use a vertical layout.
- Tap and drag swapping, row/column selection, VoiceOver labels, reduced-motion handling, persistent audio/haptic preferences, existing fantasy artwork and generated WAV audio.
- AdMob adaptive banners, rewarded ads and interstitials. UMP consent gates all requests. Reward grants originate only from the SDK callback and are idempotent in the save.

## Advertising

Debug always uses Google's **iOS test IDs**, even if publisher settings are supplied. UI tests disable network advertising.

For production, copy `Config/Publisher.example.xcconfig` to `Config/Publisher.xcconfig`, fill in your iOS app/unit IDs, Apple team and public privacy-policy URL. This file is ignored by Git. Release does not initialize ads while the sample app ID remains in place.

Configure your messages in AdMob Privacy & messaging. Interstitials appear only at post-win transitions after level 5, at least four completions apart and with three-minute session/cooldown gates. Unavailable ads never block the next level. Reward choices are +50 coins, five lives, one hammer, or doubling that attempt's win coins. No reward is granted for merely closing an ad.

The app does not request ATT tracking authorization. Reassess privacy disclosures and permissions if adding tracking or mediation. The app manifest covers its own local timer API; the SDKs carry their own manifests. Validate the merged archive privacy report and the actual enabled SDK behavior before App Store submission.

References: [Google setup](https://developers.google.com/admob/ios/quick-start), [rewarded ads](https://developers.google.com/admob/ios/rewarded), [UMP](https://developers.google.com/admob/ios/privacy), [banners](https://developers.google.com/admob/ios/banner).

## Validate on macOS

```sh
swift test
WCM_VALIDATE_CAMPAIGN=1 swift test -c release --filter MatchEngineTests/testEntireCampaignWhenRequested
xcodegen generate
python3 Scripts/select_simulator.py iPhone
xcodebuild test -project WordCrushMania.xcodeproj -scheme WordCrushMania \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' CODE_SIGNING_ALLOWED=NO
```

Use a UUID returned by the helper; repeat for iPad. The GitHub workflow performs core tests, both simulator families and an unsigned Release compilation after publication. The full campaign pass is opt-in through workflow dispatch and is a required release gate, not a claimed completed test.

## Continue development

Clone this repository on a Mac, generate the Xcode project with the instructions above and run the Apple validation workflow. No credentials, signing certificates or production configuration are included. Review [release requirements](Docs/RELEASE.md) and [asset provenance](ASSET_LICENSES.md).
