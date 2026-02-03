//
//  FlexibleDateEditor.swift
//  Timeliner
//

import SwiftUI

struct FlexibleDateEditor: View {
    let label: String
    @Binding var flexibleDate: FlexibleDate

    @State private var year: Int
    @State private var hasMonth: Bool
    @State private var month: Int
    @State private var hasDay: Bool
    @State private var day: Int
    @State private var hasTime: Bool
    @State private var hour: Int
    @State private var minute: Int

    init(label: String, flexibleDate: Binding<FlexibleDate>) {
        self.label = label
        self._flexibleDate = flexibleDate
        let fd = flexibleDate.wrappedValue
        let display = fd.localDisplayComponents
        _year = State(initialValue: display.year)
        _hasMonth = State(initialValue: fd.month != nil)
        _month = State(initialValue: display.month)
        _hasDay = State(initialValue: fd.day != nil)
        _day = State(initialValue: display.day)
        _hasTime = State(initialValue: fd.hour != nil)
        _hour = State(initialValue: display.hour)
        _minute = State(initialValue: display.minute)
    }

    var body: some View {
        Section(label) {
            // Year — always shown
            Stepper("Year: \(year)", value: $year, in: 1...9999)
                .onChange(of: year) { _, _ in writeBack() }

            // Month toggle + picker
            Toggle("Month", isOn: $hasMonth)
                .onChange(of: hasMonth) { _, on in
                    if !on { hasDay = false; hasTime = false }
                    writeBack()
                }
            if hasMonth {
                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) { m in
                        Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                    }
                }
                .onChange(of: month) { _, _ in clampDay(); writeBack() }
            }

            // Day toggle + picker (only when month is on)
            if hasMonth {
                Toggle("Day", isOn: $hasDay)
                    .onChange(of: hasDay) { _, on in
                        if !on { hasTime = false }
                        writeBack()
                    }
                if hasDay {
                    Picker("Day", selection: $day) {
                        ForEach(1...daysInMonth(), id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                    .onChange(of: day) { _, _ in writeBack() }
                }
            }

            // Time toggle + pickers (only when day is on)
            if hasDay {
                Toggle("Time", isOn: $hasTime)
                    .onChange(of: hasTime) { _, _ in writeBack() }
                if hasTime {
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
        if hasTime {
            flexibleDate = FlexibleDate.fromLocalTime(year: year, month: month, day: day, hour: hour, minute: minute)
        } else if hasDay {
            flexibleDate = FlexibleDate(year: year, month: month, day: day)
        } else if hasMonth {
            flexibleDate = FlexibleDate(year: year, month: month)
        } else {
            flexibleDate = FlexibleDate(year: year)
        }
    }
}
