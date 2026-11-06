import SwiftUI

/// Settings popover for configuring the Google Sheet URL and refresh interval.
struct SettingsView: View {
    @ObservedObject var viewModel: PortfolioViewModel
    @State private var urlInput: String = ""
    @State private var selectedInterval: TimeInterval = 30
    @Environment(\.dismiss) private var dismiss
    
    let intervalOptions: [(String, TimeInterval)] = [
        ("10 seconds", 10),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("5 minutes", 300),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
            
            // Google Sheet URL
            VStack(alignment: .leading, spacing: 6) {
                Text("Google Sheet CSV URL")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("https://docs.google.com/spreadsheets/d/.../pub?output=csv", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                
                Text("Publish your sheet: File → Share → Publish to web → CSV")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Refresh Interval
            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh Interval")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Picker("", selection: $selectedInterval) {
                    ForEach(intervalOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            // Expected Sheet Format
            VStack(alignment: .leading, spacing: 4) {
                Text("Expected sheet columns")
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    ForEach(["stock symbol", "qty", "buy price"], id: \.self) { col in
                        Text(col)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }
                
                Text("First row is treated as header and skipped.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Save / Cancel
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Save & Refresh") {
                    viewModel.sheetURL = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.refreshInterval = selectedInterval
                    dismiss()
                    Task {
                        await viewModel.refreshAll()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            urlInput = viewModel.sheetURL
            selectedInterval = viewModel.refreshInterval
        }
    }
}
