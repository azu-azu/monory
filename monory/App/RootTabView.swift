import SwiftUI
import SwiftData

struct RootTabView: View {
    @Query private var allLogs: [MovieLog]

    private var upcomingCount: Int {
        allLogs.filter(\.isUpcoming).count
    }

    var body: some View {
        TabView {
            MovieLogListView()
                .tabItem {
                    Label("ログ", systemImage: "film")
                }
            UpcomingTicketsView()
                .tabItem {
                    Label("チケット", systemImage: "ticket")
                }
                .badge(upcomingCount)
        }
        .overlay(alignment: .top) {
            GeometryReader { geo in
                StatusBarView(safeAreaTop: geo.safeAreaInsets.top)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .statusBarHidden(true)
    }
}
