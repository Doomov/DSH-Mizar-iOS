//
//  RefreshNote.swift
//  DSH-Mizar
//
//  What a refresh button says when there is nothing to refresh.
//
//  A refresh is a read on a socket. With no socket there is no progress to
//  draw, and a window that only ever fills in is a window that lies: the ring
//  stays at zero, the sheet never lands, and the operator is left holding a
//  control that appears to be working. So the button says the one thing they
//  can act on -- that the computer is not reachable -- and says it where they
//  tapped, out of the button itself.
//
//  No buttons inside, and no scrim: the note is not a decision, it is a
//  sentence. A tap or a scroll anywhere else puts it away, because the window
//  is a popover and that is what a popover does.
//

import SwiftUI

/// The sentence a refresh button shows when the computer cannot be reached.
struct RefreshUnreachableNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(Theme.waiting)
                .accessibilityHidden(true)
            Text("Can't reach the desktop. Try reconnecting.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("refresh.unreachable")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: 236, alignment: .leading)
    }
}

#Preview {
    RefreshUnreachableNote()
}
