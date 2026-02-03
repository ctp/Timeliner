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
    @State private var trackingView: NSView?

    func body(content: Content) -> some View {
        content
            .background(ScrollWheelTrackingView(trackingView: $trackingView))
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    // Only handle scroll events that originate within this view's hierarchy
                    guard let trackingView,
                          let eventWindow = event.window,
                          eventWindow == trackingView.window else {
                        return event
                    }
                    let locationInView = trackingView.convert(event.locationInWindow, from: nil)
                    guard trackingView.bounds.contains(locationInView) else {
                        return event
                    }

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

/// Captures a reference to the underlying NSView so we can hit-test scroll events.
private struct ScrollWheelTrackingView: NSViewRepresentable {
    @Binding var trackingView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { trackingView = view }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func onHorizontalScroll(_ handler: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(onHorizontalScroll: handler))
    }
}
