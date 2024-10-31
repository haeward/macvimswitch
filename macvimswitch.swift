import Cocoa
import Carbon
import Foundation

class InputSourceManager {
    static var keyboardOnly = true
    static var uSeconds: UInt32 = 20000
    
    static func initialize() {
        _ = TISCreateInputSourceList(nil, true)?.takeRetainedValue()
    }
    
    static func getCurrentSource() -> TISInputSource {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            fatalError("Failed to get current input source")
        }
        return source
    }
    
    static func getInputSource(name: String) -> TISInputSource? {
        let inputSourceNsArray = TISCreateInputSourceList(
            [kTISPropertyInputSourceID: name] as CFDictionary,
            false
        )?.takeRetainedValue() as NSArray?
        
        guard let inputSourceArray = inputSourceNsArray,
              let inputSource = inputSourceArray.firstObject,
              CFGetTypeID(inputSource as CFTypeRef) == TISInputSourceGetTypeID() else {
            return nil
        }
        
        return (inputSource as! TISInputSource)
    }
}

// 添加代理协议
protocol KeyboardManagerDelegate: AnyObject {
    func keyboardManagerDidUpdateState()
}

class KeyboardManager {
    static let shared = KeyboardManager()
    weak var delegate: KeyboardManagerDelegate?  // 添加代理属性
    private var eventTap: CFMachPort?
    let abcInputSource = "com.apple.keylayout.ABC"
    var useShiftSwitch: Bool = false {
        didSet {
            print("useShiftSwitch changed from \(oldValue) to \(useShiftSwitch)")
            delegate?.keyboardManagerDidUpdateState()  // 通知代理状态更新
        }
    }
    var lastShiftPressTime: TimeInterval = 0
    
    // 添加属性来跟踪上一个输入法
    private var lastInputSource: String?
    private var isShiftPressed = false
    private var lastKeyDownTime: TimeInterval = 0  // 修改变量名使其更明确
    private var isKeyDown = false  // 添加新变量跟踪是否有按键被按下
    
    private var keyDownTime: TimeInterval = 0  // 记录最后一次按键时间
    private var lastFlagChangeTime: TimeInterval = 0  // 记录最后一次修饰键变化时间
    
    private var keySequence: [TimeInterval] = []  // 记录按键序列的时间戳
    private var lastKeyEventTime: TimeInterval = 0  // 记录最后一次按键事件的时间
    private static let KEY_SEQUENCE_WINDOW: TimeInterval = 0.3  // 按键序列的时间窗口
    
    private var shiftPressStartTime: TimeInterval = 0  // 记录 Shift 按下的开始时间
    private var hasOtherKeysDuringShift = false       // 记录 Shift 按下期间是否有其他键按下
    
    private init() {
        // 移除通知相关的初始化
    }
    
    func start() {
        InputSourceManager.initialize()
        setupEventTap()
        showInitialInstructions()
    }
    
    private func showInitialInstructions() {
        let alert = NSAlert()
        alert.messageText = "MacVimSwitch 使用说明"
        alert.informativeText = """
            1. 按 ESC 键会自动切换到英文输入法
            2. 提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
            3. 可选功能：使用 Shift 切换输入法（默认关闭）
            
            注意：程序需要辅助功能权限才能正常工作。
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "启用 Shift 切换")
        
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self.enableShiftSwitch()
            }
        }
    }
    
    private func enableShiftSwitch() {
        let alert = NSAlert()
        alert.messageText = "启用 Shift 切换前须知"
        alert.informativeText = """
            请先关闭输入法中的 Shift 切换中英文功能，否则可能会产生冲突。
            
            操作步骤：
            1. 打开输入法偏好设置
            2. 关闭"使用 Shift 切换中英文"选项
            """
        alert.alertStyle = .warning
        alert.runModal()
        
        useShiftSwitch = true  // 这会触发代理方法
    }
    
    private func setupEventTap() {
        // 修改事件掩码，添加 keyUp 事件的监听
        let eventMask = (1 << CGEventType.keyDown.rawValue) | 
                       (1 << CGEventType.keyUp.rawValue) | 
                       (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap")
            exit(1)
        }
        
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    func switchInputMethod() {
        print("Attempting to switch input method")
        let currentSource = InputSourceManager.getCurrentSource()
        
        guard let currentSourceIdRef = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
            print("Failed to get current source ID")
            return
        }
        let currentSourceId = Unmanaged<CFString>.fromOpaque(currentSourceIdRef).takeUnretainedValue() as String
        print("Current input source: \(currentSourceId)")
        
        if let lastSource = lastInputSource {
            // 如果当前是 ABC，切换到上一个输入法
            if currentSourceId == abcInputSource {
                print("Switching to last input method: \(lastSource)")
                if let source = InputSourceManager.getInputSource(name: lastSource) {
                    TISSelectInputSource(source)
                }
            } else {
                // 如果当前不是 ABC，切换到 ABC，并记住当前输入法
                lastInputSource = currentSourceId
                if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
                    print("Switching to ABC input method")
                    TISSelectInputSource(abcSource)
                }
            }
        } else {
            // 如果没有上一个输入法记录，记录当前输入法并切换到 ABC
            if currentSourceId != abcInputSource {
                lastInputSource = currentSourceId
                if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
                    print("Switching to ABC input method (first time)")
                    TISSelectInputSource(abcSource)
                }
            }
        }
    }
    
    // 修改方法来处理其他修饰键的状态
    func handleModifierFlags(_ flags: CGEventFlags) {
        let currentTime = Date().timeIntervalSince1970
        
        print("""
            Flag event analysis:
            - Raw flags value: \(String(format: "0x%X", flags.rawValue))
            - Has other keys: \(hasOtherKeysDuringShift)
            - Is Shift pressed: \(isShiftPressed)
            - useShiftSwitch enabled: \(useShiftSwitch)
            """)
        
        // 检查是否是 Shift 按下事件（0x20102）或释放事件（0x100）
        if flags.rawValue == 0x20102 {  // Shift 按下
            if !isShiftPressed {
                isShiftPressed = true
                shiftPressStartTime = currentTime
                hasOtherKeysDuringShift = false
                print("Shift key pressed down")
            }
        } else if flags.rawValue == 0x100 {  // Shift 释放
            if isShiftPressed {
                let pressDuration = currentTime - shiftPressStartTime
                print("Shift key released, duration: \(pressDuration), hasOtherKeys: \(hasOtherKeysDuringShift)")
                
                // 只有在启用了 Shift 切换，且没有其他键被按下，且按下时间不太长时才触发切换
                if useShiftSwitch && !hasOtherKeysDuringShift && pressDuration < 0.5 {
                    print("Conditions met, triggering input source switch")
                    switchInputMethod()
                } else {
                    print("""
                        Switch not triggered because:
                        - Shift switch enabled: \(useShiftSwitch)
                        - No other keys: \(!hasOtherKeysDuringShift)
                        - Press duration OK: \(pressDuration < 0.5)
                        """)
                }
            }
            isShiftPressed = false
            hasOtherKeysDuringShift = false
        }
    }
    
    private func cleanupKeySequence(_ currentTime: TimeInterval) {
        // 移除超过时间窗口的按键记录
        keySequence = keySequence.filter { 
            currentTime - $0 < KeyboardManager.KEY_SEQUENCE_WINDOW 
        }
    }
    
    private func shouldTriggerSwitch(_ currentTime: TimeInterval) -> Bool {
        // 如果在时间窗口内有其他按键事件，不触发切换
        if keySequence.count > 1 {
            return false
        }
        
        // 如果最近有其他按键事件，不触发切换
        if currentTime - lastKeyDownTime < 0.1 {
            return false
        }
        
        return true
    }
    
    // 修改键盘事件记录方法
    func handleKeyDown(_ down: Bool) {
        if down {
            if isShiftPressed {
                // 如果在 Shift 按下期间有其他键被按下
                hasOtherKeysDuringShift = true
                print("Other key pressed while Shift is down")
            }
        }
    }
    
    // 添加新方法：专门用于ESC键的切换
    func switchToABC() {
        print("Switching to ABC input method")
        if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
            TISSelectInputSource(abcSource)
            print("Successfully switched to ABC input method")
        } else {
            print("Failed to get ABC input source")
        }
    }
}

private func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()
    
    switch type {
    case .keyDown:
        manager.handleKeyDown(true)
        
        if event.getIntegerValueField(.keyboardEventKeycode) == 0x35 { // ESC key
            print("ESC key pressed")
            manager.switchToABC()
        }
        
    case .keyUp:
        manager.handleKeyDown(false)
        
    case .flagsChanged:
        let flags = event.flags
        print("Flag changed event: \(flags.rawValue)")
        manager.handleModifierFlags(flags)
        
    default:
        break
    }
    
    return Unmanaged.passRetained(event)
}

// 主程序入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

class AppDelegate: NSObject, NSApplicationDelegate, KeyboardManagerDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu: NSMenu?  // 添加菜单属性
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置代理
        KeyboardManager.shared.delegate = self
        
        // 先设置状态栏
        setupStatusBarItem()
        // 然后启动键盘管理器
        KeyboardManager.shared.start()
        
        // 显示初始使用提示
        showInitialInstructions()
    }
    
    private func setupStatusBarItem() {
        if let button = statusItem.button {
            updateStatusBarIcon()
            
            // 直接设置菜单，而不是使用 action
            createAndShowMenu()
            
            // 确保按钮可用
            button.isEnabled = true
        }
    }
    
    private func showInitialInstructions() {
        let alert = NSAlert()
        alert.messageText = "MacVimSwitch 使用说明"
        alert.informativeText = """
            1. 按 ESC 键会自动切换到英文输入法
            2. 提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
            3. 可选功能：使用 Shift 切换输入法（默认关闭）
            
            注意：程序需要辅助功能权限才能正常工作。
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "启用 Shift 切换")
        
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self.enableShiftSwitch()
            }
        }
    }
    
    private func enableShiftSwitch() {
        let alert = NSAlert()
        alert.messageText = "启用 Shift 切换前须知"
        alert.informativeText = """
            请先关闭输入法中的 Shift 切换中英文功能，否则可能会产生冲突。
            
            操作步骤：
            1. 打开输入法偏好设置
            2. 关闭"使用 Shift 切换中英文"选项
            """
        alert.alertStyle = .warning
        alert.runModal()
        
        KeyboardManager.shared.useShiftSwitch = true
        updateStatusBarIcon()
        createAndShowMenu()
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem.button else {
            print("Status item button not found")
            return
        }
        
        if KeyboardManager.shared.useShiftSwitch {
            button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "MacVimSwitch (Shift Enabled)")
        } else {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacVimSwitch")
        }
        
        // 确保按钮可用
        button.isEnabled = true
    }
    
    private func createAndShowMenu() {
        print("Creating menu, current shift switch state: \(KeyboardManager.shared.useShiftSwitch)")
        
        let newMenu = NSMenu()
        
        // 添加使用说明菜单项
        newMenu.addItem(NSMenuItem(title: "使用说明", action: #selector(showInstructions), keyEquivalent: ""))
        newMenu.addItem(NSMenuItem.separator())
        
        // 根据当前状态显示不同的菜单项文字
        let shiftSwitchTitle = KeyboardManager.shared.useShiftSwitch ? 
            "关闭 Shift 切换输入法" : "启用 Shift 切换输入法"
        
        let shiftSwitchItem = NSMenuItem(
            title: shiftSwitchTitle,
            action: #selector(toggleShiftSwitch),
            keyEquivalent: ""
        )
        shiftSwitchItem.target = self
        newMenu.addItem(shiftSwitchItem)
        
        newMenu.addItem(NSMenuItem.separator())
        newMenu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // 设置菜单
        statusItem.menu = newMenu
        self.menu = newMenu
    }
    
    @objc private func toggleShiftSwitch() {
        print("Toggle shift switch called, current state: \(KeyboardManager.shared.useShiftSwitch)")
        
        // 切换状态
        KeyboardManager.shared.useShiftSwitch = !KeyboardManager.shared.useShiftSwitch
        
        print("State after toggle: \(KeyboardManager.shared.useShiftSwitch)")
        
        // 更新状态栏图标
        updateStatusBarIcon()
        
        // 使用 NSAlert 替代通知
        if KeyboardManager.shared.useShiftSwitch {
            DispatchQueue.main.async { [weak self] in
                let alert = NSAlert()
                alert.messageText = "Shift 切换已启用"
                alert.informativeText = "请确保已关闭输入法中的 Shift 切换中英文选项"
                alert.alertStyle = .informational
                alert.runModal()
                
                // 确保警告框关闭后重新创建菜单
                self?.createAndShowMenu()
            }
        } else {
            // 如果是关闭操作，直接重新创建菜单
            createAndShowMenu()
        }
    }
    
    @objc private func showInstructions() {
        let alert = NSAlert()
        alert.messageText = "使用说明"
        alert.informativeText = """
            1. 按 ESC 键会自动切换到英文输入法
            2. CapsLock 短按可以切换输入法，长按才是锁定大写
            3. 如果启用了 Shift 切换功能，请确保已关闭输入法的 Shift 切换设置
            """
        alert.runModal()
    }
    
    // 实现代理方法
    func keyboardManagerDidUpdateState() {
        updateStatusBarIcon()
        createAndShowMenu()
    }
} 