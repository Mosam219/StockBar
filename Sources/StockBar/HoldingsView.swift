import SwiftUI

/// The main popover view showing portfolio summary and individual holdings.
struct HoldingsView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerSection
            
            Divider()
            
            if viewModel.sheetURL.isEmpty {
                setupPrompt
            } else if viewModel.isLoading && viewModel.holdings.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.holdings.isEmpty {
                errorView(error)
            } else {
                // MARK: - Holdings List
                holdingsList
            }
            
            Divider()
            
            // MARK: - Footer
            footerSection
        }
        .frame(minWidth: 350, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                // Space for macOS traffic light buttons (close, minimize, zoom)
                Spacer()
                    .frame(width: 58)
                
                Text("StockBar")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                
                marketStateIndicator
                
                Button(action: {
                    NSApp.keyWindow?.orderOut(nil)
                }) {
                    Image(systemName: "minus.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide window")
            }
            .padding(.top, 4)
            
            if !viewModel.holdings.isEmpty {
                summaryCard
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 6) {
            // Total Portfolio Value
            HStack {
                Text("Portfolio Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.formatCurrency(viewModel.summary.totalCurrent))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            HStack(spacing: 16) {
                // Total P&L
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total P&L")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(viewModel.formatCurrency(viewModel.summary.totalPnL))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.summary.isProfitable ? .green : .red)
                        Text(viewModel.formatPercent(viewModel.summary.totalPnLPercent))
                            .font(.caption2)
                            .foregroundColor(viewModel.summary.isProfitable ? .green : .red)
                    }
                }
                
                Spacer()
                
                // Day P&L
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Day P&L")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.formatCurrency(viewModel.summary.dayPnL))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.summary.isDayPositive ? .green : .red)
                }
            }
            
            // Invested
            HStack {
                Text("Invested")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.formatCurrency(viewModel.summary.totalInvested))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Market State Indicator
    private var marketStateIndicator: some View {
        let state = viewModel.holdings.first?.marketState ?? "CLOSED"
        let isLive = state == "REGULAR" || state == "LIVE"
        
        return HStack(spacing: 4) {
            Circle()
                .fill(isLive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(isLive ? "LIVE" : "SYNCED")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Holdings List
    private var holdingsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.holdings) { holding in
                    holdingRow(holding)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Holding Row
    private func holdingRow(_ holding: LiveHolding) -> some View {
        HStack {
            // Left: Symbol & Qty
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text("\(holding.quantity) shares · Avg \(viewModel.formatPrice(holding.buyPrice))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Right: Price & P&L
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.formatPrice(holding.currentPrice))
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    // Day change
                    Text(viewModel.formatPercent(holding.dayChangePercent))
                        .font(.caption2)
                        .foregroundColor(holding.isDayPositive ? .green : .red)
                    
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Total P&L
                    Text("\(viewModel.formatCurrency(holding.totalPnL))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(holding.isProfitable ? .green : .red)
                    
                    Text(viewModel.formatPercent(holding.totalPnLPercent))
                        .font(.caption2)
                        .foregroundColor(holding.isProfitable ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        HStack {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(lastUpdated, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                Task { await viewModel.refreshAll() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Refresh all data")
            
            Button(action: {
                showSettings.toggle()
            }) {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .popover(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Quit StockBar")
        }
        .padding(10)
    }
    
    // MARK: - Empty / Error States
    
    private var setupPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Connect Your Google Sheet")
                .font(.headline)
            
            Text("Click the ⚙️ gear icon below to add your published Google Sheet CSV URL.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Fetching holdings...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await viewModel.refreshAll() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(30)
    }
}
