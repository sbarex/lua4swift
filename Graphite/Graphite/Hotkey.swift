import Foundation
import AppKit

private let lazilySetupHotkeys: Void = SDegutisSetupHotkeyCallback(Hotkey.callback)
private typealias chk = Hotkey // because otherwise swift crashes
private var enabledHotkeys = [UInt32 : chk]()

public class Hotkey {
    
    public enum Mod {
        case Command
        case Control
        case Option
        case Shift
        
        public init?(_ str: String) {
            switch str.lowercaseString {
            case "command", "cmd": self = Command
            case "control", "ctrl": self = Control
            case "option", "opt", "alt": self = Option
            case "shift": self = Shift // good old shift, only going by one name
            default: return nil
            }
        }
        
        public func toCarbonFlag() -> Int {
            switch self {
            case .Command: return cmdKey
            case .Control: return controlKey
            case .Option: return optionKey
            case .Shift: return shiftKey
            }
        }
    }
    
    public typealias Callback = () -> ()
    
    public let key: String
    public let mods: [Mod]
    public let downFn: Callback
    public let upFn: Callback?
    
    var carbonHotkey: UnsafeMutablePointer<Void>?
    
    public convenience init(key: String, mods: [String], downFn: Callback, upFn: Callback? = nil) {
        let mods: [Mod?] = mods.map{Mod($0)}
        self.init(key: key, mods: mods, downFn: downFn, upFn: upFn)
    }
    
    public convenience init(key: String, mods: [Mod?], downFn: Callback, upFn: Callback? = nil) {
        let mods = mods.filter{$0 != nil}.map{$0!}
        self.init(key: key, mods: mods, downFn: downFn, upFn: upFn)
    }
    
    public init(key: String, mods: [Mod], downFn: Callback, upFn: Callback? = nil) {
        self.key = key
        self.mods = mods
        self.downFn = downFn
        self.upFn = upFn
    }
    
    public func enable() -> (Bool, String) {
        lazilySetupHotkeys
        
        if self.carbonHotkey != nil { return (false, "Hotkey already enabled; disable first.") }
        
        let code = Keycode.codeForKey(key)
        if code == nil { return (false, "Hotkey's key is not valid.") }
        
        let id = UInt32(enabledHotkeys.count)
        enabledHotkeys[id] = self
        
        let carbonModFlags = map(self.mods) { $0.toCarbonFlag() }
        self.carbonHotkey = SDegutisRegisterHotkey(id, UInt32(code!), UInt32(reduce(carbonModFlags, 0, |)))
        
        return (true, "")
    }
    
    public func disable() {
        if self.carbonHotkey == nil { return }
        SDegutisUnregisterHotkey(self.carbonHotkey!)
        self.carbonHotkey = nil
    }
    
    public class func callback(i: UInt32, down: Bool) -> Bool {
        if let hotkey = enabledHotkeys[i] {
            if down {
                hotkey.downFn()
            }
            else if let upFn = hotkey.upFn {
                upFn()
            }
        }
        
        return false
    }
    
}