import Charts
import SwiftUI

public struct ChartValuePoint: Identifiable, Hashable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct PerformanceChartView: View {
    public let points: [ChartValuePoint]
    public let selectedRangeTitle: String
    public let rangeTitles: [(id: String, title: String, accessibility: String)]
    public let selectedRangeID: String
    public let qualityLabel: String
    public let disclosure: String
    public let qualityIsWarning: Bool
    public let onSelectRangeID: (String) -> Void

    @State private var scrubbed: ChartValuePoint?

    public init(
        points: [ChartValuePoint],
        selectedRangeTitle: String,
        rangeTitles: [(id: String, title: String, accessibility: String)],
        selectedRangeID: String,
        qualityLabel: String,
        disclosure: String,
        qualityIsWarning: Bool,
        onSelectRangeID: @escaping (String) -> Void
    ) {
        self.points = points
        self.selectedRangeTitle = selectedRangeTitle
        self.rangeTitles = rangeTitles
        self.selectedRangeID = selectedRangeID
        self.qualityLabel = qualityLabel
        self.disclosure = disclosure
        self.qualityIsWarning = qualityIsWarning
        self.onSelectRangeID = onSelectRangeID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PortfolioSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(rangeTitles, id: \.id) { range in
                        Button(range.title) {
                            onSelectRangeID(range.id)
                        }
                        .buttonStyle(.bordered)
                        .tint(range.id == selectedRangeID ? PortfolioColor.accent : .secondary)
                        .accessibilityLabel(range.accessibility)
                        .accessibilityAddTraits(range.id == selectedRangeID ? .isSelected : [])
                    }
                }
            }

            if points.isEmpty {
                Text("No historical points for this range yet.")
                    .font(PortfolioTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                chart
                Text(qualityLabel)
                    .font(PortfolioTypography.caption)
                    .foregroundStyle(qualityIsWarning ? PortfolioColor.warning : .secondary)
                Text(disclosure)
                    .font(PortfolioTypography.caption)
                    .foregroundStyle(.secondary)
                if let scrubbed {
                    Text("\(scrubbed.date.formatted(date: .abbreviated, time: .shortened)): \(MoneyFormatting.currency(Decimal(scrubbed.value)))")
                        .font(PortfolioTypography.secondary)
                } else if let first = points.first, let last = points.last {
                    ChangeIndicator(
                        amount: Decimal(last.value - first.value),
                        period: selectedRangeTitle
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var chart: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Time", point.date),
                y: .value("Value", point.value)
            )
            AreaMark(
                x: .value("Time", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(PortfolioColor.accent.opacity(0.12))
        }
        .frame(height: 180)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3))
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    scrubbed = nearest(to: date)
                                }
                            }
                            .onEnded { _ in scrubbed = nil }
                    )
            }
        }
        .accessibilityLabel("Performance chart")
        .accessibilityHint("Drag to scrub values")
    }

    private func nearest(to date: Date) -> ChartValuePoint? {
        points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else {
            return "Empty \(selectedRangeTitle) chart, \(qualityLabel)"
        }
        return "\(selectedRangeTitle) chart from \(MoneyFormatting.currency(Decimal(first.value))) to \(MoneyFormatting.currency(Decimal(last.value))), \(qualityLabel)"
    }
}
