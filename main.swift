import Cocoa
import Carbon

struct MacVimSwitch {
    static func checkAccessibilityPermission() -> Bool {
        // 检查是否已经有权限
        if AXIsProcessTrusted() {
            return true
        }
        
        // 如果没有权限，检查是否可以请求权限
        let options = NSDictionary(dictionary: [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true])
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        return accessibilityEnabled
    }
}

// 主程序入口点
print("应用程序启动...")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

print("检查辅助功能权限...")
// 检查辅助功能权限并使用系统内置提示
if !MacVimSwitch.checkAccessibilityPermission() {
    print("没有获得辅助功能权限，应用程序退出...")
    exit(1)
}

print("设置应用程序激活策略...")
app.setActivationPolicy(.accessory)  // 将应用程序设置为配件类型
NSApp.activate(ignoringOtherApps: true)  // 确保应用程序被激活

print("运行应用程序主循环...")
app.run()
