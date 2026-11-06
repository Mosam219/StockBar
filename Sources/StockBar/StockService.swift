import Foundation

/// Fetches live stock quotes from Yahoo Finance v8 chart API.
class StockService {
    
    private let session: URLSession
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Fetches live quotes for multiple symbols concurrently.
    /// Resilient: if one symbol fails or gets rate-limited, others still succeed.
    /// - Parameter symbols: Array of Yahoo Finance symbols (e.g., ["BSE.NS", "DRREDDY.NS"])
    /// - Returns: Dictionary mapping symbol to StockQuote
    func fetchQuotes(for symbols: [String]) async -> [String: StockQuote] {
        guard !symbols.isEmpty else { return [:] }
        
        return await withTaskGroup(of: (String, StockQuote?).self) { group in
            for symbol in symbols {
                group.addTask {
                    let quote = await self.fetchSingleQuote(symbol: symbol)
                    return (symbol, quote)
                }
            }
            
            var quotes: [String: StockQuote] = [:]
            for await (symbol, quote) in group {
                if let quote = quote {
                    quotes[symbol] = quote
                }
            }
            return quotes
        }
    }
    
    // MARK: - Single Quote Fetch
    
    private func fetchSingleQuote(symbol: String) async -> StockQuote? {
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encodedSymbol)?range=1d&interval=1d") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let meta = decoded.chart?.result?.first?.meta,
                  let price = meta.regularMarketPrice else {
                return nil
            }
            
            let prevClose = meta.previousClose ?? meta.chartPreviousClose ?? price
            let change = price - prevClose
            let changePercent = prevClose > 0 ? (change / prevClose) * 100 : 0
            
            return StockQuote(
                symbol: symbol,
                currentPrice: price,
                previousClose: prevClose,
                dayChange: change,
                dayChangePercent: changePercent,
                marketState: "LIVE"
            )
        } catch {
            return nil
        }
    }
}
