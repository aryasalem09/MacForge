import SwiftUI

/// Notch-first navigation: the island is the product, the desktop utilities
/// are grouped as helpers underneath.
struct SidebarView: View {
    @Binding var selection: SidebarDestination?

    var body: some View {
        List(selection: $selection) {
            Section("Notch Island") {
                ForEach(SidebarDestination.notchSection) { destination in
                    link(destination)
                }
            }
            Section("Helpers") {
                ForEach(SidebarDestination.helperSection) { destination in
                    link(destination)
                }
            }
            Section {
                ForEach(SidebarDestination.generalSection) { destination in
                    link(destination)
                }
            }
        }
        .navigationTitle("MacForge")
        .listStyle(.sidebar)
        .frame(minWidth: 210)
    }

    private func link(_ destination: SidebarDestination) -> some View {
        NavigationLink(value: destination) {
            Label(destination.title, systemImage: destination.symbolName)
        }
    }
}
