import SwiftUI

/// Splash held until `AppContainer.modelLoadProgress` hits 1.0. Layout:
/// title centered upper third, 266 x 6 pt progress bar centered middle,
/// "Powered by " + `PoweredByZetic` image asset just below, beta-disclaimer
/// fine-print line at the bottom safe-area edge.
struct ModelLoadingView: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        GeometryReader { geo in
            ZStack {
                UIConfig.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: geo.size.height * 0.18)

                    Text(UIStrings.appTitle)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(UIConfig.inkGreen)

                    Spacer()

                    progressBar
                        .frame(width: 266, height: 6)
                        .padding(.bottom, UIConfig.Spacing.md)

                    poweredBy
                        .padding(.bottom, UIConfig.Spacing.lg)

                    Spacer()

                    Text(UIStrings.betaDisclaimer)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(UIConfig.inkGreen.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, UIConfig.Spacing.lg)
                        .padding(.bottom, UIConfig.Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        // Fixed-rect track + ink-green dot fill. We render the dot with a
        // rounded rectangle so the leading edge stays crisp at low progress.
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(UIConfig.sage.opacity(0.2))
                Capsule()
                    .fill(UIConfig.inkGreen)
                    .frame(width: max(6, proxy.size.width * container.modelLoadProgress))
                    .animation(.easeInOut(duration: 0.2), value: container.modelLoadProgress)
            }
        }
    }

    @ViewBuilder
    private var poweredBy: some View {
        HStack(spacing: 6) {
            Text(UIStrings.poweredByPrefix)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(UIConfig.inkGreen.opacity(0.7))
            Image(UIStrings.poweredByZeticAsset)
                .resizable()
                .scaledToFit()
                .frame(height: 18)
        }
    }
}

#Preview {
    ModelLoadingView()
        .environment(\.appContainer, AppContainer.preview)
}
