import AppKit
import Carbon.HIToolbox

final class HotkeyService {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onFire: () -> Void
    private let signature: OSType = OSType(0x434C4250) // "CLBP"
    private let hkID: UInt32 = 1

    init(onFire: @escaping () -> Void) {
        self.onFire = onFire
        installEventHandler()
    }

    deinit {
        if let ref = hotkeyRef { UnregisterEventHotKey(ref) }
        if let h = eventHandlerRef { RemoveEventHandler(h) }
    }

    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        let hkid = EventHotKeyID(signature: signature, id: hkID)
        let status = RegisterEventHotKey(
            keyCode,
            carbonFlags(from: modifiers),
            hkid,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        if status != noErr {
            NSLog("HotkeyService: RegisterEventHotKey failed with status=%d", status)
        }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let me = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { me.onFire() }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandlerRef
        )
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if flags.contains(.command) { c |= UInt32(cmdKey) }
        if flags.contains(.shift)   { c |= UInt32(shiftKey) }
        if flags.contains(.option)  { c |= UInt32(optionKey) }
        if flags.contains(.control) { c |= UInt32(controlKey) }
        return c
    }
}
