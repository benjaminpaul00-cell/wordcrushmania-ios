# Release preparation

This is a native iOS source implementation awaiting Apple build/runtime validation. An unsigned build or a passing parser is not a release approval.

1. Run all checks in VALIDATION.md. Run the optional exhaustive campaign solver validation and review its actual result.
2. Confirm the bundle identifier `com.corticallabs.wordcrushmania.ios` and minimum iOS/iPadOS 17 support with your Apple account and target devices.
3. Supply Apple signing/provisioning and the actual iOS AdMob IDs in the ignored Publisher.xcconfig. Android ad IDs must not be reused. Debug retains official test units.
4. Configure UMP messages and test consent states. Review the target audience and SDK configuration before enabling ads in production. No child-directed or under-age setting has been inferred from the game theme.
5. Supply a real public privacy-policy URL, App Store disclosures, support URL, app-ads.txt, age rating, screenshots and store description. Review the merged SDK privacy report. The app's own privacy manifest is not a substitute for declarations about Google or future mediation partners.
6. Verify the media provenance. The existing generated artwork and CC0 vocabulary/generated audio are included; the externally supplied music/sound library is excluded pending rights review.
7. Test offline play, insufficient lives, resume after process termination, full-disk/save failures and recovery. Review long-term save growth; receipts and level records are intentionally persistent to prevent duplicate rewards.
8. Use physical iPhone and iPad devices to assess touch targets, battery, audio session behavior, rendering and accessibility. Run TestFlight before publishing.

Publisher configuration and production delivery have not been verified. No Apple account, AdMob account or store listing was changed by this work.
