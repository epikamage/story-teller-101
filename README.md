## Story Teller 101

Fast, private, on-device reader for text, images, and PDFs. Imports documents, performs OCR locally, auto-splits into chapters, stores in a SwiftData library, and offers natural on-device Text-to-Speech with adjustable voices. No server dependency.

### Features
- **Import**: Files app, Share Sheet, Camera (OCR), Photos, Clipboard. Types: `.txt`, `.rtf` (plain text), `.pdf`, `.jpg/.png`.
- **Parsing & OCR**: PDFKit text extraction; Vision on-device OCR fallback for scanned pages and images.
- **Chapterization**: Heuristics for headings (Chapter/Prologue/Epilogue, roman numerals), spacing/size cues when available, and a fallback fixed-window splitter.
- **Library**: SwiftData-backed `Book`/`Chapter` models; thumbnails planned; quick browse and search (search UI WIP).
- **Reader UI**: SwiftUI with scalable type, themes (light/dark/sepia WIP), adjustable line height/margins (WIP), chapter list with progress.
- **Text-to-Speech**: AVSpeechSynthesizer on-device; adjustable rate and pitch; per-character voice mapping scaffolded (profile UI WIP); background audio planned.
- **Accessibility & Intl**: Dynamic Type support; multi-language OCR; planned language detection per chapter for best TTS voice.
- **Privacy**: 100% on-device; no analytics; optional app lock (planned).

### Tech Specs
- **Target**: iOS 17+
- **UI**: SwiftUI, NavigationStack
- **Data**: SwiftData models `Book`, `Chapter`, `VoiceProfile`, `ImportAsset`
- **Import**: PDFKit, UIDocumentPicker, Share Extension (planned), PhotosUI, VisionKit (camera OCR planned)
- **OCR/ML**: Vision `VNRecognizeTextRequest`; NaturalLanguage (language ID/tokenization planned)
- **Audio**: AVSpeechSynthesizer, AVAudioSession; MPNowPlayingInfoCenter (planned)
- **Background**: BGProcessingTask for long OCR (planned)
- **Testing**: XCTest, XCUITest (to be added)

### Data Model (SwiftData)
- **Book**: `id`, `title`, `author?`, `language?`, `createdAt`, `coverThumb?`, `sourceType`, `chapters`, `assets`
- **Chapter**: `id`, `index`, `title`, `text`, `characterMap?`, `progress`, `book`
- **VoiceProfile**: `id`, `name`, `defaultVoiceId`, `perCharacter`
- **ImportAsset**: `id`, `kind`, `fileBookmark?`, `pageCount?`, `ocrLanguageHints?`, `checksum?`, `book`

### Architecture
1. SwiftUI app with SwiftData model container.
2. Import flow parses PDFs or reads text; images use Vision OCR.
3. Chapterizer heuristics select boundaries; fallback fixed-size segmentation.
4. Reader and TTS controls per chapter; persistence of progress.

### Getting Started
1. Open `story-teller-101.xcodeproj` in Xcode 16+.
2. Select an iOS Simulator (iOS 17+) or device.
3. Build & Run. In the Library, tap Import to choose a `.txt` or `.pdf`.

### Roadmap
- v1.0: Text/PDF/Image import, OCR, chapterization, SwiftData library, TTS, search.
- v1.1: iCloud sync (CloudKit) and export/import bundles.
- v1.2: EPUB (non-DRM), basic character diarization assist.
- v1.3: On-device summarization and smart bookmarks.

### Privacy & Security
- All processing is on-device. No network required.
- Data stored in the app sandbox. App lock via LocalAuthentication planned.

### License
TBD

