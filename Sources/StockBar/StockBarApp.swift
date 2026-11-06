import SwiftUI
import AppKit

@main
struct StockBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let viewModel = PortfolioViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menubar only
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupWindow()
        
        // Initial data fetch
        Task { @MainActor in
            await viewModel.refreshAll()
            viewModel.startTimer()
        }
        
        // Observe viewModel changes for menubar title updates
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenubarTitle()
            }
        }
    }
    
    // MARK: - Status Bar Item
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "📈 StockBar"
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }
    
    private func updateMenubarTitle() {
        if let button = statusItem.button {
            button.title = viewModel.menubarTitle
        }
    }
    
    // MARK: - Floating Movable Window
    
    private func setupWindow() {
        let hostingController = NSHostingController(
            rootView: HoldingsView(viewModel: viewModel)
        )
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 340, height: 400)
        window.setFrameAutosaveName("StockBarMainWindow")
        
        // Default position: top right near menu bar
        if !window.setFrameUsingName("StockBarMainWindow") {
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.maxX - 400
                let y = screenRect.maxY - 560
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            
            Task { @MainActor in
                await viewModel.refreshPrices()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopTimer()
    }
}
