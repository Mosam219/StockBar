import Foundation

// MARK: - Holding (from Google Sheet)
struct SheetHolding: Identifiable {
    let id = UUID()
    let symbol: String              // e.g., "BSE"
    let quantity: Int
    let buyPrice: Double
    let sheetCurrentPrice: Double?  // price from sheet if present
    let sheetTodayUpPercent: Double? // today up % from sheet if present
    
    /// Yahoo Finance symbol (append .NS for NSE)
    var yahooSymbol: String {
        return "\(symbol).NS"
    }
}

// MARK: - Live Quote
struct StockQuote {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
    let dayChange: Double
    let dayChangePercent: Double
    let marketState: String  // "REGULAR", "PRE", "POST", "CLOSED"
}

// MARK: - Combined Holding with Live Data
struct LiveHolding: Identifiable {
    let id = UUID()
    let symbol: String
    let quantity: Int
    let buyPrice: Double
    let currentPrice: Double
    let dayChange: Double
    let dayChangePercent: Double
    let marketState: String
    
    var investedValue: Double {
        return Double(quantity) * buyPrice
    }
    
    var currentValue: Double {
        return Double(quantity) * currentPrice
    }
    
    var totalPnL: Double {
        return currentValue - investedValue
    }
    
    var totalPnLPercent: Double {
        guard investedValue > 0 else { return 0 }
        return (totalPnL / investedValue) * 100
    }
    
    var dayPnL: Double {
        return Double(quantity) * dayChange
    }
    
    var isProfitable: Bool {
        return totalPnL >= 0
    }
    
    var isDayPositive: Bool {
        return dayChange >= 0
    }
}

// MARK: - Portfolio Summary
struct PortfolioSummary {
    let totalInvested: Double
    let totalCurrent: Double
    let totalPnL: Double
    let totalPnLPercent: Double
    let dayPnL: Double
    let holdingsCount: Int
    
    var isProfitable: Bool {
        return totalPnL >= 0
    }
    
    var isDayPositive: Bool {
        return dayPnL >= 0
    }
    
    static let empty = PortfolioSummary(
        totalInvested: 0, totalCurrent: 0,
        totalPnL: 0, totalPnLPercent: 0,
        dayPnL: 0, holdingsCount: 0
    )
}

// MARK: - Yahoo Finance v8 Chart Models
struct YahooChartResponse: Codable {
    let chart: ChartBody?
}

struct ChartBody: Codable {
    let result: [ChartResult]?
    let error: ChartError?
}

struct ChartError: Codable {
    let code: String?
    let description: String?
}

struct ChartResult: Codable {
    let meta: ChartMeta?
}

struct ChartMeta: Codable {
    let symbol: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
    let exchangeName: String?
}
