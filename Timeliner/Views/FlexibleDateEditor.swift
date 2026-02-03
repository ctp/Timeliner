//
//  FlexibleDateEditor.swift
//  Timeliner
//

import SwiftUI

struct FlexibleDateEditor: View {
    let label: String
    @Binding var flexibleDate: FlexibleDate

    @State private var precision: DatePrecision
    @State private var year: Int
    @State private var month: Int
    @State private var day: Int
    @State private var hour: Int
    @State private var minute: Int

    init(label: String, flexibleDate: Binding<FlexibleDate>) {
        self.label = label
        self._flexibleDate = flexibleDate
        let fd = flexibleDate.wrappedValue
        let display = fd.localDisplayComponents
        if fd.hour != nil {
            _precision = State(initialValue: .time)
        } else if fd.day != nil {
            _precision = State(initialValue: .day)
        } else if fd.month != nil {
            _precision = State(initialValue: .month)
        } else {
            _precision = State(initialValue: .year)
        }
        _year = State(initialValue: display.year)
        _month = State(initialValue: display.month)
        _day = State(initialValue: display.day)
        _hour = State(initialValue: display.hour)
        _minute = State(initialValue: display.minute)
    }

    var body: some View {
        Section(label) {
            Picker("Precision", selection: $precision) {
                ForEach(DatePrecision.allCases, id: \.self) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: precision) { _, _ in writeBack() }

            Stepper("Year: \(year, format: .number.grouping(.never))", value: $year, in: 1...9999)
                .onChange(of: year) { _, _ in writeBack() }

            if precision >= .month {
                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) { m in
                        Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                    }
                }
                .onChange(of: month) { _, _ in clampDay(); writeBack() }
            }

            if precision >= .day {
                Picker("Day", selection: $day) {
                    ForEach(1...daysInMonth(), id: \.self) { d in
                        Text("\(d)").tag(d)
                    }
                }
                .onChange(of: day) { _, _ in writeBack() }
            }

            if precision >= .time {
                Picker("Hour", selection: $hour) {
                    ForEach(0...23, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .onChange(of: hour) { _, _ in writeBack() }
                Picker("Minute", selection: $minute) {
                    ForEach(0...59, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .onChange(of: minute) { _, _ in writeBack() }
            }
        }
    }

    private func daysInMonth() -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let cal = Calendar.current
        if let date = cal.date(from: comps),
           let range = cal.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }

    private func clampDay() {
        let maxDay = daysInMonth()
        if day > maxDay { day = maxDay }
    }

    private func writeBack() {
        switch precision {
        case .time:
            flexibleDate = FlexibleDate.fromLocalTime(year: year, month: month, day: day, hour: hour, minute: minute)
        case .day:
            flexibleDate = FlexibleDate(year: year, month: month, day: day)
        case .month:
            flexibleDate = FlexibleDate(year: year, month: month)
        case .year:
            flexibleDate = FlexibleDate(year: year)
        }
    }
}
