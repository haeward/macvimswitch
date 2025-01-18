import Cocoa

class LaunchManager {
    static let shared = LaunchManager()
    
    private init() {}
    
    func isLaunchAtLoginEnabled() -> Bool {
        if let loginItems = try? FileManager.default.contentsOfDirectory(atPath: "/Users/\(NSUserName())/Library/Application Support/com.apple.backgroundtaskmanagementagent/BackgroundItems.btm") {
            return loginItems.contains(where: { $0.contains("MacVimSwitch") })
        }
        return false
    }
    
    func toggleLaunchAtLogin() {
        let bundlePath = Bundle.main.bundlePath

        if isLaunchAtLoginEnabled() {
            // 使用 AppleScript 移除登录项
            let script = """
                tell application "System Events"
                    delete login item "MacVimSwitch"
                end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("Error removing login item: \(error)")
                }
            }
        } else {
            // 使用 AppleScript 添加登录项
            let script = """
                tell application "System Events"
                    make new login item at end with properties {path:"\(bundlePath)", hidden:false}
                end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("Error adding login item: \(error)")
                }
            }
        }
    }
}
