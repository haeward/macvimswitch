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
    
    static func isCJKVSource(_ source: TISInputSource) -> Bool {
        guard let langRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages),
              let languages = Unmanaged<CFArray>.fromOpaque(langRef).takeUnretainedValue() as? [String],
              let lang = languages.first else {
            return false
        }
        
        return lang == "ko" || lang == "ja" || lang == "vi" || lang.hasPrefix("zh")
    }
    
    static func getNonCJKVSource() -> TISInputSource? {
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        
        return inputSources.first { source in
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else {
                return false
            }
            let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as String
            return category == (kTISCategoryKeyboardInputSource as String) && !isCJKVSource(source)
        }
    }
    
    static func getSourceID(_ source: TISInputSource) -> String? {
        guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as String
    }
    
    static func getSourceName(_ source: TISInputSource) -> String? {
        guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String
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
    var useShiftSwitch: Bool = true {
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
    private var lastFlagChangeTime: TimeInterval = 0  // 记录最后一次修饰键变化时���
    
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
        
        // 找到第一个��� ABC 的中文输入法
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
        guard let currentSourceId = InputSourceManager.getSourceID(currentSource) else {
            return
        }
        
        // 如果还没有找到中文输入法，尝试初始化
        if lastInputSource == nil && currentSourceId != abcInputSource {
            lastInputSource = currentSourceId
        }
        
        if let lastSource = lastInputSource {
            if currentSourceId == abcInputSource {
                // 从 ABC 切换到上一个输入法
                if let source = InputSourceManager.getInputSource(name: lastSource) {
                    if InputSourceManager.isCJKVSource(source) {
                        switchToCJKV(source)
                    } else {
                        TISSelectInputSource(source)
                        usleep(InputSourceManager.uSeconds)
                    }
                }
            } else {
                // 从其他输入法切换到 ABC
                if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
                    // 保存当前输入法作为上一个输入法
                    lastInputSource = currentSourceId
                    
                    // 使用特殊序列切换到 ABC
                    TISSelectInputSource(abcSource)
                    usleep(InputSourceManager.uSeconds)
                    
                    // 验证切换结果
                    let finalSource = InputSourceManager.getCurrentSource()
                    if let finalSourceId = InputSourceManager.getSourceID(finalSource),
                       finalSourceId != abcInputSource {
                        // 如果失败，尝试另一种切换序列
                        if let currentSource = InputSourceManager.getInputSource(name: currentSourceId),
                           InputSourceManager.isCJKVSource(currentSource) {
                            if let nonCJKV = InputSourceManager.getNonCJKVSource() {
                                TISSelectInputSource(nonCJKV)
                                usleep(InputSourceManager.uSeconds)
                                TISSelectInputSource(abcSource)
                                usleep(InputSourceManager.uSeconds)
                            }
                        } else {
                            TISSelectInputSource(abcSource)
                            usleep(InputSourceManager.uSeconds)
                        }
                    }
                }
            }
        } else {
            if currentSourceId != abcInputSource {
                lastInputSource = currentSourceId
            }
            initializeInputSources()
        }
        
        delegate?.keyboardManagerDidUpdateState()
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
            let currentSource = InputSourceManager.getCurrentSource()
            if let currentSourceId = InputSourceManager.getSourceID(currentSource),
               currentSourceId != abcInputSource {
                // 保存当前输入法
                lastInputSource = currentSourceId
                
                // 使用特殊序列切换到 ABC
                TISSelectInputSource(abcSource)
                usleep(InputSourceManager.uSeconds)
                
                // 验证切换结果
                let finalSource = InputSourceManager.getCurrentSource()
                if let finalSourceId = InputSourceManager.getSourceID(finalSource),
                   finalSourceId != abcInputSource {
                    // 如果失败，尝试另一种切换序列
                    if InputSourceManager.isCJKVSource(currentSource) {
                        if let nonCJKV = InputSourceManager.getNonCJKVSource() {
                            TISSelectInputSource(nonCJKV)
                            usleep(InputSourceManager.uSeconds)
                            TISSelectInputSource(abcSource)
                            usleep(InputSourceManager.uSeconds)
                        }
                    }
                }
            }
            
            delegate?.keyboardManagerDidUpdateState()
        }
    }
    
    func setLastInputSource(_ sourceId: String) {
        if let source = InputSourceManager.getInputSource(name: sourceId) {
            // 直接切换到选择的输入法
            if InputSourceManager.isCJKVSource(source) {
                switchToCJKV(source)
            } else {
                TISSelectInputSource(source)
                usleep(InputSourceManager.uSeconds)
            }
            
            // 更新 lastInputSource
            lastInputSource = sourceId
            print("Set last input source to: \(sourceId)")
            
            // 通知状态更新
            delegate?.keyboardManagerDidUpdateState()
        }
    }
    
    // 添加新的辅助方法来处理 CJKV 输入法切换
    private func switchToCJKV(_ source: TISInputSource) {
        // 第一步：切换到目标输入法
        TISSelectInputSource(source)
        usleep(InputSourceManager.uSeconds)
        
        // 第二步：切换到 ABC
        if let abcSource = InputSourceManager.getInputSource(name: abcInputSource) {
            TISSelectInputSource(abcSource)
            usleep(InputSourceManager.uSeconds)
            
            // 第三步：再切回目标输入法
            TISSelectInputSource(source)
            usleep(InputSourceManager.uSeconds)
            
            // 第四步：验证切换结果
            let finalSource = InputSourceManager.getCurrentSource()
            if let finalSourceId = InputSourceManager.getSourceID(finalSource),
               finalSourceId != InputSourceManager.getSourceID(source) {
                // 如果切换失败，尝试使用另一种序列
                if let nonCJKV = InputSourceManager.getNonCJKVSource() {
                    TISSelectInputSource(nonCJKV)
                    usleep(InputSourceManager.uSeconds)
                    TISSelectInputSource(source)
                    usleep(InputSourceManager.uSeconds)
                }
            }
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
        // print("Flag changed event: \(flags.rawValue)")
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
            重要提示：
            1. 请先关闭输入法中的"使用 Shift 切换中英文"选项，否则会产生冲突
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
    
    private func enableShiftSwitch() {
        let alert = NSAlert()
        alert.messageText = "启用 Shift 切换前须知"
        alert.informativeText = """
            1. 请先关输入法中的 Shift 切换中英文功能，否则可能会产生冲突。
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
                item.representedObject = sourceId
                if sourceId == KeyboardManager.shared.lastInputSource {
                    item.state = .on
                }
                inputMethodMenu.addItem(item)
            }
        }
        
        newMenu.addItem(inputMethodItem)
        newMenu.addItem(NSMenuItem.separator())
        
        // 修改 Shift 切换选项的文字
        let shiftSwitchItem = NSMenuItem(
            title: "使用 Shift 切换输入法",
            action: #selector(toggleShiftSwitch),
            keyEquivalent: ""
        )
        shiftSwitchItem.target = self
        shiftSwitchItem.state = KeyboardManager.shared.useShiftSwitch ? .on : .off
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
        var seenNames = Set<String>()  // 用于追踪已经添加的输入法名称
        
        for source in inputSources {
            // 获取输入法类别
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as? String,
                  category == kTISCategoryKeyboardInputSource as String else {
                continue
            }
            
            // 检查输入法是否启用
            guard let enabledRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled),
                  let enabled = Unmanaged<CFBoolean>.fromOpaque(enabledRef).takeUnretainedValue() as? Bool,
                  enabled else {
                continue
            }
            
            // 检查是否是主要输入源
            guard let isPrimaryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable),
                  let isPrimary = Unmanaged<CFBoolean>.fromOpaque(isPrimaryRef).takeUnretainedValue() as? Bool,
                  isPrimary else {
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
            
            // 排除 ABC 输入法和已经添加过的输入法名称
            if sourceId != KeyboardManager.shared.abcInputSource && !seenNames.contains(name) {
                methods.append((sourceId, name))
                seenNames.insert(name)
            }
        }
        
        // 按名称排序
        return methods.sorted { $0.1 < $1.1 }
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