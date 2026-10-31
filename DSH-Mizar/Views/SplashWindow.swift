//
//  SplashWindow.swift
//  DSH-Mizar
//
//  The splash, in a window of its own.
//
//  It cannot be an overlay or a cover on the app's own view: the shell is
//  hosted in its own view controller (the drawer container bridges into UIKit),
//  and that controller draws *above* anything the SwiftUI root presents. The
//  splash was therefore rendered -- a red one covered the bottom half of the
//  screen in a capture -- and the app was drawn over the top of it.
//
//  A window at `alert` level is above every view controller in the app, which
//  is the same trick a launch screen uses. It is added once, taken away once,
//  and never touches the app's own hierarchy.
//

import SwiftUI
import UIKit

/// One window, above the app's, that holds the launch mark.
@MainActor
final class SplashWindow {
    /// The window, while it is up.
    private var window: UIWindow?

    /// Put the mark on screen.
    ///
    /// - Parameters:
    ///   - model: the app model the mark reads its phase from.
    ///   - onFinished: called once the mark has left, after the window is gone.
    func show(model: AppModel, onFinished: @escaping () -> Void) {
        guard window == nil else { return }
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let scene else {
            onFinished()
            return
        }
        let host = UIHostingController(
            rootView: SplashView {
                onFinished()
            }
            .environment(model)
            // The mark is drawn from paths at the display's scale; a hosting
            // controller in a window of its own starts with none, and a shape
            // drawn at zero scale is a shape that is not there. This is why the
            // page and a plain circle appeared and the mark did not.
            .environment(\.displayScale, scene.screen.scale),
        )
        host.view.backgroundColor = .clear
        // The mark's ink is chosen from the appearance: the icon's blue on a
        // light screen, white on a dark one. A window of its own starts with no
        // opinion, and a white star on the light page is a splash with nothing
        // on it -- which is exactly what a capture showed. It follows the app.
        let keyWindow = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
        host.overrideUserInterfaceStyle = keyWindow?.overrideUserInterfaceStyle ?? .unspecified
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    /// Take the window away.
    func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}
