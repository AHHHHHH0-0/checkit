import Foundation
import CoreVideo

/// Per-frame orchestrator for the offline identify pipeline.
/// - Runs YOLO11.
/// - For plant-allowlist detections, runs the plant classifier on the crop.
/// - Looks up the resulting scientific name in the active region pack.
/// - Hands the frame's tracked detections + per-detection `DetectionState` upward.
actor InferenceWorker {

    struct FrameOutcome: Sendable {
        let detections: [TrackedDetection]
        let states: [UUID: DetectionState]
        let frameSize: CGSize
    }

    private let detection: any ObjectDetectionServiceProtocol
    private let plant: any PlantClassificationServiceProtocol
    private let knowledge: OfflinePlantKnowledgeService
    private let tracker: BoxTracker
    private let telemetry: InferenceTelemetry

    private var stateCache: [UUID: DetectionState] = [:]
    private var lastClassifiedFor: [UUID: String] = [:]

    init(
        detection: any ObjectDetectionServiceProtocol,
        plant: any PlantClassificationServiceProtocol,
        knowledge: OfflinePlantKnowledgeService,
        tracker: BoxTracker,
        telemetry: InferenceTelemetry
    ) {
        self.detection = detection
        self.plant = plant
        self.knowledge = knowledge
        self.tracker = tracker
        self.telemetry = telemetry
    }

    func process(frame: CameraFrame) async -> FrameOutcome? {
        let started = Date()
        guard let raws = await detection.detect(in: frame) else { return nil }
        let tracked = await tracker.update(with: raws)
        let frameSize = CGSize(
            width: CVPixelBufferGetWidth(frame.pixelBuffer),
            height: CVPixelBufferGetHeight(frame.pixelBuffer)
        )

        var states: [UUID: DetectionState] = [:]
        for det in tracked {
            if !ModelConfig.YOLO.plantClassAllowlist.contains(det.yoloClass) {
                states[det.id] = .notFood(yoloClass: det.yoloClass)
                continue
            }
            // Reuse the cached state when we already have one for this stable id.
            if let cached = stateCache[det.id] {
                states[det.id] = cached
            } else {
                states[det.id] = .blank
            }
        }

        // Run the plant classifier against the highest-confidence plant box only,
        // to keep latency below the per-frame budget. Other plant boxes inherit
        // the cached state until they become the top candidate.
        if let topPlant = tracked
            .filter({ ModelConfig.YOLO.plantClassAllowlist.contains($0.yoloClass) })
            .max(by: { $0.confidence < $1.confidence }) {
            if let prediction = await plant.classify(crop: topPlant.bbox, in: frame) {
                let resolved = await knowledge.resolve(yoloClass: topPlant.yoloClass, scientificName: prediction.scientificName)
                stateCache[topPlant.id] = resolved
                lastClassifiedFor[topPlant.id] = prediction.scientificName
                states[topPlant.id] = resolved
                let scientificName = prediction.scientificName
                let lookupStatus = Self.statusLabel(for: resolved)
                let yoloClass = topPlant.yoloClass
                Task { @MainActor in
                    telemetry.lastDetectionClass = yoloClass
                    telemetry.lastScientificName = scientificName
                    telemetry.lastLookupStatus = lookupStatus
                }
            }
        }

        let elapsedMs = Date().timeIntervalSince(started) * 1000
        Task { @MainActor in
            telemetry.recordFrame()
            telemetry.lastInferenceLatencyMs = elapsedMs
        }
        return FrameOutcome(detections: tracked, states: states, frameSize: frameSize)
    }

    func reset() async {
        stateCache.removeAll()
        lastClassifiedFor.removeAll()
        await tracker.reset()
    }

    private static func statusLabel(for state: DetectionState) -> String {
        switch state {
        case .blank: return "blank"
        case .edible: return "edible"
        case .inedible: return "inedible"
        case .poisonous: return "poisonous"
        case .notFound: return "not found"
        case .notFood: return "not food"
        }
    }
}
