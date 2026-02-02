//
//  ScrollWheelOverlay.swift
//  Timeliner
//

import SwiftUI
import AppKit

/// A view modifier that observes scroll wheel events via an NSEvent local monitor.
/// The monitor reads horizontal deltas for time panning and returns the event
/// unchanged so the SwiftUI ScrollView still handles vertical lane scrolling.
struct ScrollWheelModifier: ViewModifier {
    var onHorizontalScroll: (CGFloat) -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    let dx: CGFloat
                    if event.hasPreciseScrollingDeltas {
                        dx = event.scrollingDeltaX
                    } else {
                        dx = event.scrollingDeltaX * 10
                    }

                    if abs(dx) > 0 {
                        onHorizontalScroll(dx)
                    }

                    // Return the event unchanged so vertical scrolling still works
                    return event
                }
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
                monitor = nil
            }
    }
}

extension View {
    func onHorizontalScroll(_ handler: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(onHorizontalScroll: handler))
    }
}
