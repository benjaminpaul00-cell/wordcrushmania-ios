# Verification status — 7 November 2026

## Executed on Windows

- Swift syntax-tree parsing of 17 `.swift` files with tree-sitter-swift: no ERROR or missing nodes.
- Parsed `project.yml` and the GitHub workflow as YAML.
- Parsed Info.plist and PrivacyInfo.xcprivacy as property lists.
- Checked asset-catalog JSON references, decoded all packaged PNGs, and read all six WAV headers.
- Checked the English thematic lexicon against the Android Dictionary's allowed words and theme lists: 809 list entries.
- Generated an opaque RGB 1024×1024 icon using the existing logo.

These are static/source and resource checks. They do **not** establish Swift type correctness, successful linking, gameplay correctness, visual quality, ad delivery or App Store readiness.

## Written, not executed

- Seven engine tests: horizontal/vertical/reverse matches; invalid/diagonal/wrapped swaps; target-only and duplicate rejection; blocked tiles, gravity IDs and cascade bound; guided boosters and bomb region; deterministic generation and solver checks at difficulty boundaries; optional 10,000-level campaign validation.
- Seven persistence/progression tests: settings/time round trip; one-life timeout; idempotent rewarded grants and session-bound doubling; daily rollback protection; inventory and rejected-turn charging; corruption/schema rejection; single finish reward.
- One iOS UI test: launch, first tutorial, board, pause/resume and accessible tile selection, with screenshot attachment.
- GitHub Actions workflow: core tests, iPhone and iPad UI tests, and unsigned iOS Release build.

## Still required

1. Execute the GitHub Apple validation workflow, or run Xcode locally on macOS. Resolve every compiler/linker/test failure.
2. Execute the full generated campaign validation in Release mode. Generation is bounded and throws recoverable errors; no exhaustive success result is claimed.
3. Review actual screenshots on small/large iPhone, iPad mini/large iPad, landscape and resized windows; test Dynamic Type, VoiceOver, Reduce Motion and long text.
4. Measure generation/boosters and animation frame time on physical devices. The core calculations use detached tasks; performance has not been measured.
5. Test process termination, background/foreground, audio interruptions, ad presentation/dismissal, consent errors and changes, lack of network, no fill, callback duplication and save write failure.
6. Supply publisher-owned iOS AdMob configuration, consent messages, privacy-policy URL and Apple signing. Validate actual rewarded and interstitial behavior using test devices.

## Deliberate differences and scope

- Rules follow the active Android swap engine, not its legacy path-selection engine.
- iOS has its own explicitly versioned SplitMix64/shuffle generator. Level numbers, themes, goals, rewards and sizes follow the campaign structure, but boards and target draws are not byte-identical to Android. No cross-platform save migration or cloud synchronization is provided.
- Automatic recovery and safe booster checks use the active engine's legal moves rather than the legacy proofPath. Hammer on an entirely frozen tutorial board invokes verified recovery; the bomb tutorial opens a playable word only inside the chosen 3×3 region.
- App settings are honored and remaining time is persisted. Lives do not regenerate automatically, consistent with the current Android tests.
- Interface and vocabulary are English. No functioning French mode is claimed.
- Six original generated WAV files are bundled. The supplied third-party MP3 playlist and OGG sound library have not been redistributed or converted.
- No Firebase telemetry, StoreKit purchases, push notifications, Game Center or iCloud synchronization is enabled.
- Only one scene/session is supported; the interface still adapts to iPad window size.

## Repository

The owner created `benjaminpaul00-cell/wordcrushmania-ios`. The source package includes the Apple validation workflow; consult the repository's Actions tab for actual build and test results. This document does not claim that those jobs have passed.
