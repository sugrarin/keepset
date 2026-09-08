# Keepset

macOS app for culling a photo folder: keep the shots you want, send the rest to Recently Deleted.

**Keepset** (`com.keepset.app`) currently works with a local `photos/` sandbox and the system Camera Roll.

Version `0.1.0`. Platform: macOS 14+, Swift 6, SwiftUI + AppKit.

```
xcodebuild -project Keepset.xcodeproj -scheme Keepset -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Keepset.app
```

See `project.md` for product behavior and architecture.
