import SwiftUI

/// Natives macOS Settings-Fenster mit 4 Tabs.
struct SettingsView: View {
    @ObservedObject var processor: FileProcessor
    let database: DatabaseManager

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("Allgemein", systemImage: "gearshape")
                }

            FoldersTab(processor: processor)
                .tabItem {
                    Label("Ordner", systemImage: "folder")
                }

            AITab()
                .tabItem {
                    Label("KI", systemImage: "cpu")
                }

            ActivityTab(processor: processor, database: database)
                .tabItem {
                    Label("Aktivität", systemImage: "clock.arrow.circlepath")
                }
        }
        .frame(minWidth: 550, minHeight: 450)
    }
}
