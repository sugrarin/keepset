# Trasher

- After every code change, rebuild the macOS app before finishing. Do not leave a change unbuilt.
- Build with:

  ```
  xcodebuild -project Trasher.xcodeproj -scheme Trasher -configuration Debug build
  ```

- After a successful build, relaunch `Trasher.app` so the running app matches the new binary.
- After finishing a requested change, commit and push. Do not leave the work only local.
