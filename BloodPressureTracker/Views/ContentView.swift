import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var calendarResetID = UUID()
    @State private var trendsResetID = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .id(calendarResetID)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("日历")
                }
                .tag(0)

            AddReadingView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("添加")
                }
                .tag(1)

            TrendsView()
                .id(trendsResetID)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("趋势")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("设置")
                }
                .tag(3)
        }
        .tint(Color.accentColor)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 0 {
                calendarResetID = UUID()
            } else if newValue == 2 {
                trendsResetID = UUID()
            }
        }
    }
}
