import Cocoa
import Carbon

class InputMethodManager {
    static let shared = InputMethodManager()
    
    private init() {}
    
    func getAvailableInputMethods() -> [(String, String)]? {
        guard let inputSources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        var methods: [(String, String)] = []
        var seenNames = Set<String>()

        for source in inputSources {
            // 获取输入法类别
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                  let category = (Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as NSString) as String?,
                  category == kTISCategoryKeyboardInputSource as String else {
                continue
            }

            // 检查输入法是否启用
            guard let enabledRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
                continue
            }
            let enabled = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(enabledRef).takeUnretainedValue())
            guard enabled else { continue }

            // 检查是否是主要输入源
            guard let isPrimaryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
                continue
            }
            let isPrimary = CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(isPrimaryRef).takeUnretainedValue())
            guard isPrimary else { continue }

            // 获取输入法 ID
            guard let sourceIdRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let sourceId = (Unmanaged<CFString>.fromOpaque(sourceIdRef).takeUnretainedValue() as NSString) as String? else {
                continue
            }

            // 获取输入法名称
            guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                  let name = (Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as NSString) as String? else {
                continue
            }

            // 排除 ABC 输入法和已经添加过的输入法名称
            if sourceId != KeyboardManager.shared.abcInputSource && !seenNames.contains(name) {
                methods.append((sourceId, name))
                seenNames.insert(name)
            }
        }

        return methods.sorted { $0.1 < $1.1 }
    }
}
