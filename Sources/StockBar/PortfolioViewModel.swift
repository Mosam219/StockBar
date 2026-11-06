import Foundation
import SwiftUI
import Combine

/// Main ViewModel that orchestrates data fetching and state management.
@MainActor
class PortfolioViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var holdings: [LiveHolding] = []
    @Published var summary: PortfolioSummary = .empty
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var sheetURL: String {
        didSet {
            UserDefaults.standard.set(sheetURL, forKey: "sheetURL")
        }
    }
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            restartTimer()
        }
    }
    
    // MARK: - Services
    private let sheetsService = GoogleSheetsService()
    private let stockService = StockService()
    private var refreshTimer: Timer?
    
    // MARK: - Menubar Title
    var menubarTitle: String {
        guard !holdings.isEmpty else {
            return "📈 StockBar"
        }
        
        let pnl = summary.dayPnL
        let sign = pnl >= 0 ? "+" : ""
        let emoji = pnl >= 0 ? "📈" : "📉"
        
        return "\(emoji) \(sign)\(formatCurrency(pnl))"
    }
    
    // MARK: - Init
    init() {
        self.sheetURL = UserDefaults.standard.string(forKey: "sheetURL") ?? ""
        self.refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        if self.refreshInterval == 0 {
            self.refreshInterval = 30 // default 30 seconds
        }
    }
    
    // MARK: - Data Fetching
    
    /// Full refresh: fetch holdings from sheet, then fetch live prices.
    func refreshAll() async {
        guard !sheetURL.isEmpty else {
            errorMessage = "Please set your Google Sheet URL in Settings"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Fetch holdings from Google Sheet
            let sheetHoldings = try await sheetsService.fetchHoldings(from: sheetURL)
            
            guard !sheetHoldings.isEmpty else {
                errorMessage = "No active holdings found in your sheet."
                isLoading = false
                return
            }
            
            // Step 2: Fetch live prices from Yahoo Finance
            let yahooSymbols = sheetHoldings.map { $0.yahooSymbol }
            let quotes = await stockService.fetchQuotes(for: yahooSymbols)
            
            // Step 3: Combine holdings with live data (fallback to sheet data)
            var liveHoldings: [LiveHolding] = []
            
            for holding in sheetHoldings {
                if let quote = quotes[holding.yahooSymbol] {
                    liveHoldings.append(LiveHolding(
                        symbol: holding.symbol,
                        quantity: holding.quantity,
                        buyPrice: holding.buyPrice,
                        currentPrice: quote.currentPrice,
                        dayChange: quote.dayChange,
                        dayChangePercent: quote.dayChangePercent,
                        marketState: quote.marketState
                    ))
                } else {
                    // Use price and day change from the Google Sheet formula if available
                    let price = holding.sheetCurrentPrice ?? holding.buyPrice
                    let dayChangePct = holding.sheetTodayUpPercent ?? 0
                    let dayChange = (price * dayChangePct) / 100
                    
                    liveHoldings.append(LiveHolding(
                        symbol: holding.symbol,
                        quantity: holding.quantity,
                        buyPrice: holding.buyPrice,
                        currentPrice: price,
                        dayChange: dayChange,
                        dayChangePercent: dayChangePct,
                        marketState: holding.sheetCurrentPrice != nil ? "SHEET" : "UNKNOWN"
                    ))
                }
            }
            
            // Sort by absolute total P&L (biggest movers first)
            liveHoldings.sort { abs($0.totalPnL) > abs($1.totalPnL) }
            
            self.holdings = liveHoldings
            self.summary = computeSummary(from: liveHoldings)
            self.lastUpdated = Date()
            self.errorMessage = nil
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Refresh live prices.
    func refreshPrices() async {
        guard !holdings.isEmpty else {
            await refreshAll()
            return
        }
        
        let symbols = holdings.map { "\($0.symbol).NS" }
        let quotes = await stockService.fetchQuotes(for: symbols)
        
        guard !quotes.isEmpty else { return }
        
        var updated: [LiveHolding] = []
        for holding in holdings {
            let yahooSymbol = "\(holding.symbol).NS"
            if let quote = quotes[yahooSymbol] {
                updated.append(LiveHolding(
                    symbol: holding.symbol,
                    quantity: holding.quantity,
                    buyPrice: holding.buyPrice,
                    currentPrice: quote.currentPrice,
                    dayChange: quote.dayChange,
                    dayChangePercent: quote.dayChangePercent,
                    marketState: quote.marketState
                ))
            } else {
                updated.append(holding)
            }
        }
        
        updated.sort { abs($0.totalPnL) > abs($1.totalPnL) }
        self.holdings = updated
        self.summary = computeSummary(from: updated)
        self.lastUpdated = Date()
    }
    
    // MARK: - Auto-refresh Timer
    
    func startTimer() {
        restartTimer()
    }
    
    func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func restartTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refreshPrices()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func computeSummary(from holdings: [LiveHolding]) -> PortfolioSummary {
        let totalInvested = holdings.reduce(0) { $0 + $1.investedValue }
        let totalCurrent = holdings.reduce(0) { $0 + $1.currentValue }
        let totalPnL = totalCurrent - totalInvested
        let totalPnLPercent = totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0
        let dayPnL = holdings.reduce(0) { $0 + $1.dayPnL }
        
        return PortfolioSummary(
            totalInvested: totalInvested,
            totalCurrent: totalCurrent,
            totalPnL: totalPnL,
            totalPnLPercent: totalPnLPercent,
            dayPnL: dayPnL,
            holdingsCount: holdings.count
        )
    }
    
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "₹0.00"
    }
    
    func formatPercent(_ value: Double) -> String {
        return String(format: "%+.2f%%", value)
    }
    
    func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "₹0.00"
    }
}
