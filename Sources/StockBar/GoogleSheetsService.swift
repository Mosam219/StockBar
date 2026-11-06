import Foundation

/// Fetches holdings from a Google Sheet published/exported as CSV.
/// 
/// Expected columns (by header name):
///   - "stock symbol" — NSE stock symbol (e.g., BSE)
///   - "qty" — quantity held
///   - "buy price" — average buy price
///   - "current price" (optional) — current market price from sheet formula
///   - "today up" (optional) — day change % from sheet formula
///   - "sell" (optional) — if empty, the stock is a current holding
class GoogleSheetsService {
    
    /// Fetches and parses current holdings from the Google Sheet.
    /// Only returns rows where the "sell" column is empty (i.e., not yet sold).
    func fetchHoldings(from urlString: String) async throws -> [SheetHolding] {
        let csvURL = normalizeToCSVExportURL(urlString)
        
        guard let url = URL(string: csvURL) else {
            throw GoogleSheetsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GoogleSheetsError.fetchFailed(code)
        }
        
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw GoogleSheetsError.invalidData
        }
        
        return parseCSV(csvString)
    }
    
    /// Converts various Google Sheet URL formats to the CSV export URL.
    private func normalizeToCSVExportURL(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Already a CSV export/pub URL
        if trimmed.contains("export?format=csv") || trimmed.contains("pub?output=csv") {
            return trimmed
        }
        
        // Extract the spreadsheet ID and convert to export URL
        // Patterns: /spreadsheets/d/SPREADSHEET_ID/...
        if let range = trimmed.range(of: "/spreadsheets/d/") {
            let afterD = trimmed[range.upperBound...]
            if let slashIndex = afterD.firstIndex(of: "/") {
                let spreadsheetID = String(afterD[afterD.startIndex..<slashIndex])
                // Check if there's a gid parameter for a specific sheet tab
                if let gidRange = trimmed.range(of: "gid=") {
                    let gidStart = gidRange.upperBound
                    let remaining = trimmed[gidStart...]
                    let gid = String(remaining.prefix(while: { $0.isNumber }))
                    if !gid.isEmpty {
                        return "https://docs.google.com/spreadsheets/d/\(spreadsheetID)/export?format=csv&gid=\(gid)"
                    }
                }
                return "https://docs.google.com/spreadsheets/d/\(spreadsheetID)/export?format=csv"
            }
        }
        
        return trimmed
    }
    
    /// Parses CSV string into SheetHolding array.
    private func parseCSV(_ csv: String) -> [SheetHolding] {
        let lines = parseCSVLines(csv)
        
        guard lines.count > 1 else { return [] }
        
        // Find column indices from header row
        let header = lines[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        let symbolIndex = header.firstIndex(of: "stock symbol") ?? 0
        let qtyIndex = header.firstIndex(of: "qty") ?? 1
        let buyPriceIndex = header.firstIndex(of: "buy price") ?? 2
        let currentPriceIndex = header.firstIndex(of: "current price")
        let todayUpIndex = header.firstIndex(where: { $0.contains("today") || $0.contains("change") })
        let sellIndex = header.firstIndex(of: "sell") ?? 8
        
        var holdings: [SheetHolding] = []
        
        for i in 1..<lines.count {
            let columns = lines[i]
            
            // Ensure we have symbol, qty, buyPrice columns
            guard columns.count > max(symbolIndex, qtyIndex, buyPriceIndex) else { continue }
            
            let symbol = cleanString(columns[symbolIndex])
            let qtyStr = cleanNumber(columns[qtyIndex])
            let priceStr = cleanNumber(columns[buyPriceIndex])
            
            // Check sell column if present; if non-empty, it's already sold
            let sellStr = (sellIndex < columns.count) ? cleanString(columns[sellIndex]) : ""
            guard sellStr.isEmpty else { continue }
            
            // Validate symbol
            guard !symbol.isEmpty,
                  symbol == symbol.uppercased(),
                  symbol.allSatisfy({ $0.isLetter || $0.isNumber }),
                  symbol.count >= 2, symbol.count <= 20 else {
                continue
            }
            
            guard let qty = Int(qtyStr), qty > 0,
                  let price = Double(priceStr), price > 0 else {
                continue
            }
            
            // Parse current price from sheet if available
            var sheetPrice: Double? = nil
            if let curIdx = currentPriceIndex, curIdx < columns.count {
                sheetPrice = Double(cleanNumber(columns[curIdx]))
            }
            
            // Parse today up % from sheet if available
            var sheetTodayUp: Double? = nil
            if let upIdx = todayUpIndex, upIdx < columns.count {
                let upStr = cleanNumber(columns[upIdx]).replacingOccurrences(of: "%", with: "")
                sheetTodayUp = Double(upStr)
            }
            
            holdings.append(SheetHolding(
                symbol: symbol,
                quantity: qty,
                buyPrice: price,
                sheetCurrentPrice: sheetPrice,
                sheetTodayUpPercent: sheetTodayUp
            ))
        }
        
        return holdings
    }
    
    /// Properly parses a CSV string handling quoted fields with commas and newlines.
    private func parseCSVLines(_ csv: String) -> [[String]] {
        var lines: [[String]] = []
        var currentFields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        let chars = Array(csv)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if insideQuotes {
                if char == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        insideQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    i += 1
                    continue
                }
            }
            
            if char == "\"" {
                insideQuotes = true
                i += 1
            } else if char == "," {
                currentFields.append(currentField)
                currentField = ""
                i += 1
            } else if char.isNewline {
                currentFields.append(currentField)
                currentField = ""
                
                if currentFields.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    lines.append(currentFields)
                }
                currentFields = []
                i += 1
            } else {
                currentField.append(char)
                i += 1
            }
        }
        
        if !currentField.isEmpty || !currentFields.isEmpty {
            currentFields.append(currentField)
            if currentFields.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                lines.append(currentFields)
            }
        }
        
        return lines
    }
    
    private func cleanString(_ s: String) -> String {
        return s.trimmingCharacters(in: .whitespaces)
    }
    
    private func cleanNumber(_ s: String) -> String {
        return s.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

// MARK: - Errors
enum GoogleSheetsError: LocalizedError {
    case invalidURL
    case fetchFailed(Int)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Google Sheet URL. Please check your settings."
        case .fetchFailed(let code):
            return "Failed to fetch sheet (HTTP \(code)). Make sure the sheet is shared as 'Anyone with the link'."
        case .invalidData:
            return "Could not read the sheet data."
        }
    }
}
