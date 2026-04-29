import SwiftUI

struct SidebarView: View {
    let groups: [String]
    @Binding var selectedGroup: String

    var body: some View {
        List(selection: $selectedGroup) {
            Section("Library") {
                ForEach(groups.prefix(3), id: \.self) { group in
                    Label(group, systemImage: icon(for: group))
                        .tag(group)
                }
            }

            Section("Groups") {
                ForEach(groups.dropFirst(3), id: \.self) { group in
                    Label(group, systemImage: icon(for: group))
                        .tag(group)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }

    private func icon(for group: String) -> String {
        switch group {
        case "Favorites":
            return "star"
        case "Recent":
            return "clock"
        case "All Hosts":
            return "server.rack"
        case "Jump Hosts":
            return "point.3.connected.trianglepath.dotted"
        default:
            return "folder"
        }
    }
}
