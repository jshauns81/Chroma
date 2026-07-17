//
//  LoginItem.swift
//  Chroma
//
//  Thin wrapper over ServiceManagement's modern login-item API. `SMAppService`
//  (macOS 13+) is the SIP-safe replacement for the old `LSSharedFileList` and
//  login-item helper-bundle hacks: it registers the *main app* itself to launch
//  at login, managed by the system in System Settings ▸ General ▸ Login Items.
//
//  Caveat: registration only takes effect for a signed app the system can find
//  by its bundle id — i.e. running from /Applications, not a raw DerivedData
//  build. From Xcode's build products `register()` may throw or no-op; test the
//  login behavior against an installed copy.
//

import ServiceManagement

enum LoginItem {
    /// Whether Chroma is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister the main app as a login item. Throws if the system
    /// rejects the change (e.g. an unsigned/relocated build); callers decide how
    /// loudly to surface that.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        switch (enabled, service.status) {
        case (true, let status) where status != .enabled:
            try service.register()
        case (false, .enabled):
            try service.unregister()
        default:
            break  // already in the desired state
        }
    }
}
