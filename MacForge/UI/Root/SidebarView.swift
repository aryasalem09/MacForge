import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarDestination?

    var body: some View {
        List(SidebarDestination.allCases, selection: $selection) { destination in
            NavigationLink(value: destination) {
                Label(destination.title, systemImage: destination.symbolName)
            }
        }
        .navigationTitle("MacForge")
        .listStyle(.sidebar)
        .frame(minWidth: 210)
    }
}
