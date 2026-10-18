import AppKit

@MainActor
extension PhotoStore {
    func chooseFolderWithPanel() async {
        let panel = NSOpenPanel()
        panel.message = "Choose a folder with photos to sort"
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = directory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        await chooseFolder(url)
    }
}
