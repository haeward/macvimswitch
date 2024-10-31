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
            delegate?.keyboardManagerDidUpdateState()  // 移除日志，保留代理通知
        }
    }
    var lastShiftPressTime: TimeInterval = 0
    
    // 添加属性来跟踪上一个输入法
    private(set) var lastInputSource: String?
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
    
    private func initializeInputSources() {
        // 获取所有可用的输入源
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            print("Failed to get input sources")
            return
        }
        
        // 过滤出键盘输入源
        let keyboardSources = inputSources.filter { source in
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as? String else {
                return false
            }
            return category == kTISCategoryKeyboardInputSource as String
        }
        
        // 找到第一个非 ABC 的中文输入法
        for source in keyboardSources {
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as? String else {
                continue
            }
            
            if sourceId != abcInputSource {
                lastInputSource = sourceId
                print("Found Chinese input source: \(sourceId)")
                break
            }
        }
        
        print("Initialized with input source: \(lastInputSource ?? "none")")
    }
    
    func start() {
        InputSourceManager.initialize()
        initializeInputSources()  // 添加初始化调用
        setupEventTap()
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
        let currentSource = InputSourceManager.getCurrentSource()
        
        guard let currentSourceIdRef = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
            return
        }
        let currentSourceId = Unmanaged<CFString>.fromOpaque(currentSourceIdRef).takeUnretainedValue() as String
        
        // 如果还没有找到中文输入法，尝试初始化
        if lastInputSource == nil && currentSourceId != abcInputSource {
            lastInputSource = currentSourceId
        }
        
        if let lastSource = lastInputSource {
            if currentSourceId == abcInputSource {
                if let source = InputSourceManager.getInputSource(name: lastSource) {
                    TISSelectInputSource(source)
                }
            } else {
                if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
                    TISSelectInputSource(abcSource)
                }
            }
        } else {
            // 如果仍然没有找到中文输入法，重新初始化
            initializeInputSources()
        }
    }
    
    // 修改方法来处理其他修饰键的状态
    func handleModifierFlags(_ flags: CGEventFlags) {
        let currentTime = Date().timeIntervalSince1970
        
        if flags.rawValue == 0x20102 {  // Shift 按下
            if !isShiftPressed {
                isShiftPressed = true
                shiftPressStartTime = currentTime
                hasOtherKeysDuringShift = false
            }
        } else if flags.rawValue == 0x100 {  // Shift 释放
            if isShiftPressed {
                let pressDuration = currentTime - shiftPressStartTime
                
                if useShiftSwitch && !hasOtherKeysDuringShift && pressDuration < 0.5 {
                    switchInputMethod()
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
        if down && isShiftPressed {
            hasOtherKeysDuringShift = true
        }
    }
    
    // 添加新方法：专门用于ESC键的切换
    func switchToABC() {
        if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
            TISSelectInputSource(abcSource)
        }
    }
    
    func setLastInputSource(_ sourceId: String) {
        lastInputSource = sourceId
        print("Set last input source to: \(sourceId)")
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
            1. 按 ESC 键会自动切换到英文输入法 ABC
            2. 提示：在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
            3. 可选功能：使用 Shift 切换输入法（默认关闭）
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "启用 Shift 切换")
        
        DispatchQueue.main.async {
            // 创建一个新窗口并设置级别
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.level = .floating  // 设置窗口级别为浮动
            
            // 运行警告框并确保它显示在最前面
            NSApp.activate(ignoringOtherApps: true)
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
            1. 请先关��输入法中的 Shift 切换中英文功能，否则可能会产生冲突。
            2. 具体操作：打开输入法偏好设置 关闭"使用 Shift 切换中英文"选项
            3. 首次使用必须手动切换一次输入法，让程序知道需要切换的两个输入法是什么
            """
        alert.alertStyle = .warning
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)  // 激活应用并将其置于最前
            alert.runModal()
        }
        
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
        let newMenu = NSMenu()
        
        let homepageItem = NSMenuItem(title: "使用说明", action: #selector(openHomepage), keyEquivalent: "")
        homepageItem.target = self
        newMenu.addItem(homepageItem)
        
        newMenu.addItem(NSMenuItem.separator())
        
        // 添加输入法选择子菜单
        let inputMethodMenu = NSMenu()
        let inputMethodItem = NSMenuItem(title: "选择中文输入法", action: nil, keyEquivalent: "")
        inputMethodItem.submenu = inputMethodMenu
        
        // 获取所有输入法并添加到子菜单
        if let inputMethods = getAvailableInputMethods() {
            for (sourceId, name) in inputMethods {
                let item = NSMenuItem(
                    title: name,
                    action: #selector(selectInputMethod(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = sourceId  // 存储输入法 ID
                // 如果是当前选中的输入法，显示勾选标记
                if sourceId == KeyboardManager.shared.lastInputSource {
                    item.state = .on
                }
                inputMethodMenu.addItem(item)
            }
        }
        
        newMenu.addItem(inputMethodItem)
        newMenu.addItem(NSMenuItem.separator())
        
        // 添加 Shift 切换选项
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
        
        statusItem.menu = newMenu
        self.menu = newMenu
    }
    
    // 获取可用的输入法列表
    private func getAvailableInputMethods() -> [(String, String)]? {
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        
        var methods: [(String, String)] = []
        
        for source in inputSources {
            // 获取输入法类别
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as? String,
                  category == kTISCategoryKeyboardInputSource as String else {
                continue
            }
            
            // 获取输入法 ID
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as? String else {
                continue
            }
            
            // 获取输入法名称
            guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                  let name = Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as? String else {
                continue
            }
            
            // 排除 ABC 输入法
            if sourceId != KeyboardManager.shared.abcInputSource {
                methods.append((sourceId, name))
            }
        }
        
        return methods
    }
    
    @objc private func toggleShiftSwitch() {
        KeyboardManager.shared.useShiftSwitch = !KeyboardManager.shared.useShiftSwitch
        updateStatusBarIcon()
        createAndShowMenu()
    }
    
    @objc private func openHomepage() {
        if let url = URL(string: "https://github.com/Jackiexiao/macvimswitch") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func selectInputMethod(_ sender: NSMenuItem) {
        guard let sourceId = sender.representedObject as? String else { return }
        KeyboardManager.shared.setLastInputSource(sourceId)  // 需要在 KeyboardManager 中添加这个方法
        createAndShowMenu()  // 刷新菜单以更新勾选状态
    }
    
    // 实现代理方法
    func keyboardManagerDidUpdateState() {
        updateStatusBarIcon()
        createAndShowMenu()
    }
} 