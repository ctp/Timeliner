//
//  EraBandView.swift
//  Timeliner
//

import SwiftUI

struct EraBandView: View {
    let era: Era
    let viewport: TimelineViewport
    let totalHeight: CGFloat

    var body: some View {
        let startX = viewport.xPosition(for: era.startDate.asDate)
        let endX = viewport.xPosition(for: era.endDate.asDate)
        let bandWidth = endX - startX

        if bandWidth > 0 {
            ZStack {
                // Background band
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: bandWidth, height: totalHeight)
                    .mask(fadeMask(width: bandWidth))

                // Label
                Text(era.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                    )
                    .frame(width: bandWidth, height: totalHeight, alignment: .top)
                    .padding(.top, 4)
            }
            .position(x: startX + bandWidth / 2, y: totalHeight / 2)
        }
    }

    private func fadeMask(width: CGFloat) -> some View {
        let fadeZone = min(30, width * 0.15)
        let fadeRatio = fadeZone / width

        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: fadeRatio),
                .init(color: .black, location: 1 - fadeRatio),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
