import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

/// Ads use the official iOS demo IDs in Debug. Release stays off without publisher IDs.
@MainActor final class AdMobService: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var canRequestAds = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var rewardedReady = false
    @Published private(set) var presenting = false
    @Published private(set) var status: String?
    private var started = false
    private var consentRequested = false
    private var loading = false
    private var consentGeneration = 0
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var rewardedLoadedAt: Date?
    private var interstitialLoadedAt: Date?
    private var onDismiss: (() -> Void)?
    private var completedSinceAd = 0
    private var lastInterstitial = Date.distantPast
    private let launchedAt = Date()

    private var enabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return false }
        #if DEBUG
        return true
        #else
        let id = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
        return id.range(of: "^ca-app-pub-[0-9]{16}~[0-9]{10}$", options: .regularExpression) != nil && !id.contains("3940256099942544")
        #endif
    }
    var bannerID: String? { unit("AdMobBannerID", test: "ca-app-pub-3940256099942544/2435281174") }
    private func unit(_ key: String, test: String) -> String? {
        guard enabled else { return nil }
        #if DEBUG
        return test
        #else
        guard let id = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              id.range(of: "^ca-app-pub-[0-9]{16}/[0-9]{10}$", options: .regularExpression) != nil,
              !id.contains("3940256099942544") else { return nil }
        return id
        #endif
    }
    func requestConsent() {
        guard enabled, !consentRequested else { return }
        consentRequested = true
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.status = error.localizedDescription }
                else {
                    do { try await ConsentForm.loadAndPresentIfRequired(from: nil) }
                    catch { self.status = error.localizedDescription }
                }
                await self.refreshEligibility()
            }
        }
    }
    func privacyOptions() async {
        guard privacyOptionsRequired, !presenting else { return }
        consentGeneration += 1
        presenting = true
        defer { presenting = false }
        do { try await ConsentForm.presentPrivacyOptionsForm(from: nil) }
        catch { status = error.localizedDescription }
        // Drop previously loaded ads after privacy preferences change.
        rewarded = nil; interstitial = nil; rewardedReady = false
        await refreshEligibility()
    }
    private func refreshEligibility() async {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        canRequestAds = enabled && ConsentInformation.shared.canRequestAds
        guard canRequestAds else { rewarded = nil; interstitial = nil; rewardedReady = false; return }
        if !started {
            started = true
            await MobileAds.shared.start()
        }
        await preload()
    }
    func preload() async {
        guard canRequestAds, ConsentInformation.shared.canRequestAds, !loading else { return }
        loading = true
        let generation = consentGeneration
        defer { loading = false }
        if let loadedAt = rewardedLoadedAt, Date().timeIntervalSince(loadedAt) > 3500 { rewarded = nil; rewardedReady = false }
        if let loadedAt = interstitialLoadedAt, Date().timeIntervalSince(loadedAt) > 3500 { interstitial = nil }
        if rewarded == nil, let id = unit("AdMobRewardedID", test: "ca-app-pub-3940256099942544/1712485313") {
            do {
                let ad = try await RewardedAd.load(with: id, request: Request())
                guard generation == consentGeneration, canRequestAds, ConsentInformation.shared.canRequestAds else { return }
                ad.fullScreenContentDelegate = self; rewarded = ad; rewardedLoadedAt = Date(); rewardedReady = true
            } catch { status = "Rewarded ad unavailable. Try again later." }
        }
        if interstitial == nil, let id = unit("AdMobInterstitialID", test: "ca-app-pub-3940256099942544/4411468910") {
            do {
                let ad = try await InterstitialAd.load(with: id, request: Request())
                guard generation == consentGeneration, canRequestAds, ConsentInformation.shared.canRequestAds else { return }
                ad.fullScreenContentDelegate = self; interstitial = ad; interstitialLoadedAt = Date()
            } catch { status = "Interstitial unavailable." }
        }
    }
    /// The SDK's reward callback is the only path that can grant a reward.
    @discardableResult func showRewarded(grant: @escaping (String) -> Void) -> Bool {
        guard !presenting, canRequestAds, ConsentInformation.shared.canRequestAds,
              let ad = rewarded, let loadedAt = rewardedLoadedAt, Date().timeIntervalSince(loadedAt) < 3500 else {
            Task { await preload() }; return false
        }
        presenting = true; rewarded = nil; rewardedReady = false
        let token = UUID().uuidString
        var granted = false
        ad.present(from: nil) {
            guard !granted else { return }
            granted = true; grant(token)
        }
        return true
    }
    func recordCompletion() { completedSinceAd += 1 }
    func transition(after level: Int, completion: @escaping () -> Void) {
        guard !presenting else { return }
        guard canRequestAds, ConsentInformation.shared.canRequestAds, level > 5, completedSinceAd >= 4,
              Date().timeIntervalSince(launchedAt) >= 180, Date().timeIntervalSince(lastInterstitial) >= 180,
              let ad = interstitial, let loadedAt = interstitialLoadedAt, Date().timeIntervalSince(loadedAt) < 3500 else {
            completion(); Task { await preload() }; return
        }
        presenting = true; interstitial = nil; onDismiss = completion
        ad.present(from: nil)
    }
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        if onDismiss != nil { completedSinceAd = 0; lastInterstitial = Date() }
    }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { finishPresentation() }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        status = "Ad unavailable."; finishPresentation()
    }
    private func finishPresentation() {
        presenting = false
        let callback = onDismiss; onDismiss = nil; callback?()
        Task { await preload() }
    }
}

struct AdaptiveBanner: UIViewRepresentable {
    let unitID: String
    let width: CGFloat
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: largeAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = unitID
        return banner
    }
    func updateUIView(_ banner: BannerView, context: Context) {
        let size = largeAnchoredAdaptiveBanner(width: width)
        if context.coordinator.size != size.size, ConsentInformation.shared.canRequestAds {
            context.coordinator.size = size.size
            banner.adSize = size; banner.load(Request())
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var size: CGSize = .zero }
}

struct BannerSlot: View {
    @ObservedObject var ads: AdMobService
    @State private var availableSize = CGSize(width: 320, height: 600)
    var body: some View {
        if ads.canRequestAds, let id = ads.bannerID {
            let width = max(1, min(availableSize.width, 728))
            let size = largeAnchoredAdaptiveBanner(width: width)
            AdaptiveBanner(unitID: id, width: width)
                .frame(width: width, height: size.size.height)
                .frame(maxWidth: .infinity)
                .background(GeometryReader { geometry in
                    Color.clear.onAppear { availableSize = geometry.size }
                        .onChange(of: geometry.size) { _, value in availableSize = value }
                })
                .accessibilityLabel("Advertisement")
        }
    }
}
