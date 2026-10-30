//
//  SplashView.swift
//  DSH-Mizar
//
//  The first second of the app: the mark, turning, and then a camera through it.
//
//  A cold launch has nothing to show yet -- the session store is being read and
//  the socket is being dialled -- and a screen that fills in later is a screen
//  that flickers. So the app opens on the mark alone, turning at the same speed
//  the rest of the app uses for waiting, and leaves when the work is done: the
//  mark fades as it comes at the camera, so the last thing the splash shows is
//  the inside of the icon and the first thing the app shows is the page behind
//  it. The shape is the icon's, so the two halves of that cut are the same
//  drawing at two scales rather than a cut between two pictures.
//
//  The turn is the app's own `running` motion, which is linear and endless --
//  a launch of any length looks the same, and the loop's seam is invisible
//  because a whole turn per cycle starts where it ended.
//
//  Nothing here is a network state. The splash waits for `phase` to leave the
//  launching ones, and gives up after a few seconds whatever the phase says:
//  a splash that waits on a computer that is not answering would be a splash
//  that never ends.
//

import SwiftUI

/// The cold-launch splash: the mark, then the camera through it.
struct SplashView: View {
    /// Called once, when the splash has nothing left to cover.
    var onFinished: () -> Void = {}

    @Environment(AppModel.self) private var model

    /// How far the mark has come towards the camera. 1 is the resting size.
    @State private var zoom: CGFloat = 1
    /// Whether the camera move has started, so the turn can stop.
    @State private var leaving = false
    /// How long the wait for the app is allowed to last.
    private static let patience = Duration.seconds(6)

    var body: some View {
        ZStack {
            Theme.paneBackground
                .ignoresSafeArea()
            // The mark is the icon's own drawing, at the size the icon would be
            // if it were the whole screen: big enough that its arms reach past
            // the frame by the end of the move, so the camera is inside it.
            MizarStar(motion: leaving ? .still : .running, size: 88)
                .scaleEffect(zoom)
                .opacity(leaving ? 0 : 1)
        }
        .task {
            // Wait for the app to have something to show. The phases that mean
            // "still finding out" are the launching ones; anything else is an
            // answer, even if the answer is that there is no computer.
            let deadline = ContinuousClock.now + Self.patience
            while ContinuousClock.now < deadline {
                if model.phase != .launching, !(model.phase == .connecting && model.host == nil) {
                    break
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
            // A frame between the two states, so the turn stops before the
            // move rather than in the middle of it.
            leaving = true
            withAnimation(.timingCurve(0.6, 0, 1, 0.5, duration: 0.55)) {
                zoom = 22
            }
            try? await Task.sleep(for: .milliseconds(560))
            onFinished()
        }
        .accessibilityHidden(true)
    }
}
