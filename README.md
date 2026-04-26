# Checkit

> **"Are you sure it's edible?"**

Checkit is an iOS foraging assistant that uses on-device AI to identify plants and objects through your camera, assess whether they're safe to eat, and answer questions about your environment through a voice-driven AI assistant.

---

## Features

- **Live object detection** — YOLO11 draws bounding boxes around plants and objects in real time.
- **Plant identification** — Tap any box to classify the plant species from 300k species and get a streaming Gemma-powered narrative on edibility, toxicity, and preparation.
- **Voice assistant** — Press and hold to speak. Whisper transcribes your speech on-device; Gemini replies in natural language and builds a local region pack of species knowledge used offline.
- **Fully offline inference** — All vision models (YOLO, plant classifier, Whisper, Gemma) run on-device via the Zetic SDK. Only the chat assistant requires a network connection.

---

## AI Models

| Model | Provider | Role |
|-------|----------|------|
| YOLO11 | Zetic (on-device) | Real-time object detection |
| Plant classifier (300k species) | Zetic (on-device) | Plant species identification |
| Whisper tiny encoder + decoder | Zetic (on-device) | On-device speech transcription |
| Gemma 4 2B | Zetic (on-device) | Streaming plant/object narratives |
| Gemini 2.5 Flash | Google Cloud | Voice assistant replies + region pack updates |
| Vision framework | Apple (on-device) | Plant/non-plant gate before classification |

---

## How It Works

### Identify tab
1. Point your camera at a plant or object.
2. YOLO detects it and draws a bounding box.
3. Tap the box — the app runs Apple Vision to confirm it looks like a plant, then runs the PlantNet-300k classifier to identify the species.
4. Gemma streams a narrative about edibility, toxicity, and any relevant context from your region pack.

### Prepare tab
1. Press and hold to speak into the mic.
2. Whisper transcribes your speech entirely on-device.
3. Your message is sent to Gemini 2.5 Flash, which replies in the chat and updates a local region pack (a structured list of species relevant to your area).
4. The region pack is used by the Identify tab to provide richer, context-aware results offline.

---

## Setup

### Requirements
- Xcode 15+
- iOS 17+ device (on-device models require a physical device)
- [ZeticMLangeiOS](https://github.com/zetic-ai/ZeticMLangeiOS) Swift package (v1.6.0, added via Xcode Package Dependencies)

### API Keys
Create `ios/CheckIt/Secrets.xcconfig` with:

```
GEMINI_API_KEY = your_gemini_api_key
ZETIC_PERSONAL_KEY = your_zetic_personal_key
```

These are injected into `Info.plist` at build time and read via `SecretsLoader`. Do not commit this file.

### Build
1. Open `ios/CheckIt.xcodeproj` in Xcode.
2. Add the Zetic package: **File → Add Package Dependencies** → `https://github.com/zetic-ai/ZeticMLangeiOS.git` → exact version `1.6.0`.
3. Add your `Secrets.xcconfig`.
4. Build and run on a physical iOS device.

On first launch, the app downloads all five Zetic models (~several hundred MB). Progress is shown on the loading screen.

---

## Architecture

```
ContentView
├── LiveView (Identify tab)
│   ├── CameraService          — AVCaptureSession, frame delivery
│   ├── InferenceWorker        — YOLO inference per frame
│   ├── BoxTracker             — Stabilizes bounding boxes across frames
│   ├── OverlayCanvas          — Draws boxes; tap triggers DetailSheet
│   └── DetailSheet
│       ├── VisionPlantGateService     — Plant/non-plant gate
│       ├── PlantClassificationService — Species classification
│       ├── OfflinePlantKnowledgeService — Pack-based edibility resolution
│       └── GemmaReasoningService      — Streaming narrative
└── AssistantView (Prepare tab)
    ├── SpeechInputService     — AVAudioEngine mic capture
    ├── WhisperTranscriberService — On-device transcription
    └── GeminiPackService      — Chat reply + region pack update
```

All five Zetic models are loaded concurrently after permissions are granted (`ModelLoader`). Secrets, model names, and preprocessing constants are centralized in `AppConfig` and `ModelConfig`.

---

## Notes

- The app is **portrait-only** and targets **light mode**.
- The region pack and transcript are persisted to Application Support and survive restarts. Triple-tap the divider in the Prepare tab to clear them.
- A debug HUD (2-second long-press on the live view) shows FPS, detection class, and model latencies.
- This is a **beta** — plant identification should not be used as the sole basis for foraging decisions.
