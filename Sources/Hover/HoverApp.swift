import SwiftUI

@main
struct HoverApp: App {
    @StateObject private var controller = FocusController()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(controller)
        } label: {
            Image(systemName: controller.isEnabled && controller.isTrusted
                  ? "cursorarrow.motionlines" : "cursorarrow.slash")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuView: View {
    @EnvironmentObject var controller: FocusController

    var body: some View {
        if !controller.isTrusted {
            Button("Grant Accessibility Access…") {
                controller.requestTrust()
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Divider()
        }

        Toggle("Focus Follows Mouse", isOn: $controller.isEnabled)
            .keyboardShortcut("f")
        Toggle("Raise Focused Window", isOn: $controller.raiseOnFocus)

        Picker("Hover Delay", selection: $controller.delayMs) {
            ForEach(FocusController.delayOptions, id: \.self) { ms in
                Text(ms == 0 ? "Instant" : "\(ms) ms").tag(ms)
            }
        }

        Divider()
        Toggle("Launch at Login", isOn: $controller.launchAtLogin)
        Button("Quit Hover") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
