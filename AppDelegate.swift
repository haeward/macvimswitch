import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, KeyboardManagerDelegate {
    let statusBarManager = StatusBarManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用程序被激活
        NSApp.activate(ignoringOtherApps: true)

        // 确保应用不会随终端退出
        ProcessInfo.processInfo.enableSuddenTermination()

        // 设置代理
        KeyboardManager.shared.delegate = self

        // 先设置状态栏
        DispatchQueue.main.async { [weak self] in
            self?.statusBarManager.setupStatusBarItem()
        }

        // 然后启动键盘管理器
        KeyboardManager.shared.start()

        // 显示初始使用提示
        DispatchQueue.main.async { [weak self] in
            self?.showInitialInstructions()
        }
    }
    
    private func showInitialInstructions() {
        let alert = NSAlert()
        alert.messageText = "MacVimSwitch 使用说明"
        alert.informativeText = """
            重要示：
            1. 先关闭输入法中的"使用 Shift 切换中英文"选项，否则会产生冲突
            2. 具体操作：打开输入法偏好设置 → 关闭"使用 Shift 切换中英文"

            功能说明：
            1. 按 ESC 键会自动切换到英文输入法 ABC
            2. 按 Shift 键可以在中英文输入法之间切换（可在菜单栏中关闭）
            3. 提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "我已了解")

        DispatchQueue.main.async {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.level = .floating

            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    
    // 实现代理方法
    func keyboardManagerDidUpdateState() {
        statusBarManager.updateStatusBarIcon()
        statusBarManager.createAndShowMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyboardManager.shared.disableEventTap()
    }
}
