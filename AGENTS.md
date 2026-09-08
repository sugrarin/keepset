# Keepset

- After every code change, rebuild the macOS app before finishing. Do not leave a change unbuilt.
- Build with:

  ```
  xcodebuild -project Keepset.xcodeproj -scheme Keepset -configuration Debug -derivedDataPath build build
  ```

- The runnable app is `build/Build/Products/Debug/Keepset.app`. Do not leave a second copy in `~/Library/Developer/Xcode/DerivedData`.
- After a successful build, relaunch that `Keepset.app` so the running app matches the new binary.
- After finishing a requested change, commit and push. Do not leave the work only local.
