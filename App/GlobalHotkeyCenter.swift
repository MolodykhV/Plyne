import AppKit
import Carbon.HIToolbox

/// A process-global hotkey, expressed in Carbon's key-code + modifier-mask form.
struct HotkeyBinding: Equatable, Sendable {
    /// Virtual key code (e.g. `kVK_ANSI_P`).
    let keyCode: UInt32
    /// Carbon modifier mask (e.g. `controlKey | optionKey | cmdKey`).
    let carbonModifiers: UInt32
}

/// The actions Plyne exposes to a global hotkey. Customisation (a recorder UI
/// backed by UserDefaults) arrives with the settings screen in a later step;
/// for now each action has a fixed default chord.
enum HotkeyAction: CaseIterable {
    case toggleSession
    case toggleMode

    /// `⌃⌥⌘` — an uncommon chord, low collision risk, and (via Carbon's
    /// `RegisterEventHotKey`) requires no Accessibility permission.
    var defaultBinding: HotkeyBinding {
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        switch self {
        case .toggleSession:
            return HotkeyBinding(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: modifiers)
        case .toggleMode:
            return HotkeyBinding(keyCode: UInt32(kVK_ANSI_M), carbonModifiers: modifiers)
        }
    }
}

/// Registers process-global hotkeys via Carbon's `RegisterEventHotKey`.
///
/// Carbon — not `NSEvent`'s global monitors — is the right API here: it needs
/// no Accessibility permission (Plyne deliberately asks for none until the
/// activity watcher in Phase 2) and hands key presses to a single app-level
/// event handler. Carbon delivers those on the main thread, so the whole type
/// is `@MainActor`.
@MainActor
final class GlobalHotkeyCenter {
    private struct Registration {
        let ref: EventHotKeyRef
        let action: () -> Void
    }

    /// Four-char signature 'PLYN', tagging our hot-key ids so the shared
    /// handler only acts on events we registered.
    private static let signature = OSType(0x504C_594E)

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var handlerRef: EventHandlerRef?

    /// Registers `binding` to invoke `action` on press. Returns `false` if the
    /// system refused the chord (e.g. already claimed) — a missing hotkey is
    /// not fatal, every action is also reachable from the popover.
    @discardableResult
    func register(_ binding: HotkeyBinding, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        registrations[id] = Registration(ref: ref, action: action)
        return true
    }

    /// Unregisters everything (and the shared handler). Not strictly needed for
    /// a process-lifetime center, but keeps teardown tidy and testable.
    func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    /// Looks up and runs the action for a fired hot-key id. Called from the
    /// Carbon handler, already on the main thread.
    fileprivate func handle(id: UInt32) {
        registrations[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // Unretained: the center is owned for the app's lifetime, and the
        // handler only fires while the app (and thus the center) is alive.
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), plyneHotkeyHandler, 1, &spec, context, &handlerRef)
    }

    // No deinit: the center is owned by the app delegate for the whole process
    // lifetime, so it is never deallocated before exit (when the OS reclaims
    // the Carbon registrations anyway). `unregisterAll()` covers explicit
    // teardown if a future caller needs it.
}

/// C event handler for `kEventHotKeyPressed`. Top-level (no captures) so it
/// bridges to a Carbon `EventHandlerUPP` function pointer. Carbon dispatches
/// it on the main thread, so it is safe to assume `MainActor` isolation.
private func plyneHotkeyHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let context else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let center = Unmanaged<GlobalHotkeyCenter>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
        center.handle(id: hotKeyID.id)
    }
    return noErr
}
