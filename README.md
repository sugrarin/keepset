# Keepset

A small macOS app for culling photos. Instead of picking what to delete, you mark what to keep, and Keepset moves everything else out of the way. A mistake is one click from undone.

## Features

- Mark the shots you want with a click, or drag across a range
- Keep N / Delete N shows the outcome before you commit, and the All / Keep / Delete tabs let you review each group
- Undo right after deleting: the bar shows "Deleted N" with an Undo button, also on ⌘Z
- Any folder on your Mac, with a built-in Trash: Restore single photos or Empty Trash
- Camera Roll mode: unmarked photos go to Recently Deleted in Photos
- Square or original-shape tiles, grid from 3 to 10 columns
- Marks are remembered between launches, separately for each folder
- Fast on large folders: thumbnails decode off the main thread and are cached

## Requirements

- macOS 14 or later

Camera Roll mode asks for access to your photo library the first time you open it.

## Install

Download `Keepset-*.zip` from [Releases](https://github.com/sugrarin/keepset/releases), unzip it and move `Keepset.app` to `/Applications`.

The app is not notarized. On first launch, right-click it and choose Open, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Keepset.app
```

## Usage

Keepset works with two sources: the Camera Roll and a photo folder. On first launch pick the folder with **Choose Folder…** (⌘O, also in the folder menu in the top bar and on the empty screen). Keepset remembers it between launches. Show Folder in Finder is in the Folder menu.

Deleting in a folder moves files to a `.Trash` folder inside it, never to the system Trash.

| Action | Shortcut |
|---|---|
| Select all | ⌘A |
| Keep selected, delete the rest | Return |
| Undo the last delete | ⌘Z |
| Clear selection | Esc |
| Open Trash | ⇧⌘T |
| Choose a folder | ⌘O |

## Build from source

```bash
xcodebuild -project Keepset.xcodeproj -scheme Keepset -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Keepset.app
```

It needs Xcode with the Swift 6 toolchain. The project file is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), and the generated `Keepset.xcodeproj` is checked in, so XcodeGen is only needed if you change `project.yml`. Run the tests with `xcodebuild … test`.

See [project.md](project.md) for behavior and architecture.

## Third-party software

Keepset has no third-party libraries. It uses only Apple system frameworks: SwiftUI, AppKit, ImageIO and Photos.

## Support

If Keepset is useful to you, you can support me: [ko-fi.com/sugrarin](https://ko-fi.com/sugrarin)

## License

[MIT](LICENSE)
