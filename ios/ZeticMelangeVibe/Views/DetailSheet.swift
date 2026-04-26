import SwiftUI

/// Full-screen card that animates in via a custom bloom from the tapped box's
/// frame (paired with the `OverlayCanvas` `matchedGeometryEffect`). Streams a
/// Gemma narrative paragraph (in-pack / not-found paths) or shows the static
/// "this is a {class}, not food" template for non-plant detections.
struct DetailSheet: View {
    let detection: TrackedDetection
    let state: DetectionState
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @Environment(\.appContainer) private var container
    @State private var paragraph: String = ""
    @State private var streamTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            UIConfig.paper
                .ignoresSafeArea()
                .matchedGeometryEffect(id: detection.id, in: namespace, isSource: false)

            VStack(alignment: .leading, spacing: UIConfig.Spacing.lg) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: UIConfig.Spacing.md) {
                        Text(paragraph.isEmpty ? "  " : paragraph)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(UIConfig.inkGreen)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(paragraph.isEmpty ? 0.4 : 1)

                        if let rationale = rationale {
                            Text(rationale)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(rationaleColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, UIConfig.Spacing.lg)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                dismissHint
            }
            .padding(.top, UIConfig.Spacing.xl)
            .padding(.bottom, UIConfig.Spacing.lg)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            streamTask?.cancel()
            onDismiss()
        }
        .task(id: detection.id) {
            await startStreaming()
        }
        .onDisappear {
            streamTask?.cancel()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleLine)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(UIConfig.inkGreen)
            if let subtitle = subtitleLine {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(UIConfig.inkGreen.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, UIConfig.Spacing.lg)
    }

    @ViewBuilder
    private var dismissHint: some View {
        Text(UIStrings.dismissHint)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(UIConfig.inkGreen.opacity(0.45))
            .frame(maxWidth: .infinity)
    }

    private var titleLine: String {
        switch state {
        case .edible(let e), .inedible(let e), .poisonous(let e):
            return e.commonName
        case .notFound(let name):
            return name
        case .notFood(let cls):
            return cls
        case .blank:
            return "—"
        }
    }

    private var subtitleLine: String? {
        switch state {
        case .edible(let e), .inedible(let e), .poisonous(let e):
            return e.scientificName
        case .notFound:
            return UIStrings.notInLocalDatabase
        case .notFood, .blank:
            return nil
        }
    }

    private var rationale: String? {
        switch state {
        case .edible(let e), .inedible(let e), .poisonous(let e):
            return e.rationale
        case .notFood, .notFound, .blank:
            return nil
        }
    }

    private var rationaleColor: Color {
        switch state {
        case .poisonous: return UIConfig.alertRed
        default: return UIConfig.inkGreen.opacity(0.75)
        }
    }

    private func startStreaming() async {
        // Non-plant detections short-circuit to a static template — no Gemma.
        switch state {
        case .notFood(let cls):
            paragraph = staticNotFoodLine(for: cls)
            return
        case .blank:
            return
        default:
            break
        }

        let cacheKey = self.cacheKey
        if let cached = container.gemma.cachedNarrative(forKey: cacheKey) {
            paragraph = cached.paragraph
            return
        }

        paragraph = ""
        streamTask?.cancel()
        let stream: AsyncStream<String>
        switch state {
        case .edible(let e), .inedible(let e), .poisonous(let e):
            let blurb = await container.plantKnowledge.currentPrepBlurb()
            stream = container.gemma.narrate(plant: e, prepBlurb: blurb)
        case .notFound(let name):
            stream = container.gemma.narrateNotFound(scientificName: name)
        default:
            return
        }

        streamTask = Task { @MainActor in
            var buffer = ""
            for await token in stream {
                if Task.isCancelled { return }
                buffer.append(token)
                paragraph = buffer
            }
            container.gemma.cache(narrative: GemmaNarrative(key: cacheKey, paragraph: buffer))
        }
        await streamTask?.value
    }

    private var cacheKey: String {
        switch state {
        case .edible(let e), .inedible(let e), .poisonous(let e):
            return e.scientificName.lowercased()
        case .notFound(let name):
            return "notfound:" + name.lowercased()
        case .notFood(let cls):
            return "notfood:" + cls
        case .blank:
            return "blank"
        }
    }

    private func staticNotFoodLine(for cls: String) -> String {
        "this is a \(cls), not food"
    }
}
