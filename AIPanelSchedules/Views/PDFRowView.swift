import SwiftUI

struct PDFRowView: View {
    let fileName: String
    let hasBeenScanned: Bool
    let isScanning: Bool
    let isScanPending: Bool
    let isGeneratingExcel: Bool   // 👈 RIGHT HERE
    let scanStatusText: String
    let finalExcelURL: URL?

    let onViewPDF: () -> Void
    let onDelete: () -> Void
    let onScan: () -> Void
    let onGenerateExcel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                // HEader
            Button(action: onViewPDF) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.headline)
                            .lineLimit(2)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundColor(statusColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Actions
            if isScanning {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(scanStatusText)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Scanning with Gemini — this may take a couple minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.12))
                .cornerRadius(8)
            } else {
                VStack(spacing: 12) {

                    // Primary Gemini Action — full width
                    if !hasBeenScanned {

                        Button(action: onScan) {
                            Label("Scan with AI", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                    } else if hasBeenScanned && finalExcelURL == nil {

                        Button(action: onGenerateExcel) {
                            if isGeneratingExcel {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Creating Excel…")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Label("Create Excel", systemImage: "tablecells")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isGeneratingExcel)

                    } else if let url = finalExcelURL {

                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open Excel", systemImage: "tablecells")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                }
            }

         /*   // Optional download link
            if let url = finalExcelURL {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("Download .xlsx File", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            } */
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    private var statusText: String {
        if isScanning { return scanStatusText }
        if isScanPending { return "Pending (Scanner Busy)" }
        if hasBeenScanned { return "Scan Complete" }
        return "Ready"
    }

    private var statusColor: Color {
        if isScanning { return .primary }   // 👈 FIX
        if hasBeenScanned { return .green }
        return .secondary
    }

    private var scanButtonTitle: String {
        if isScanning { return scanStatusText }
        if isScanPending { return "Pending" }
        return "Scan with AI"
    }

    private var scanButtonIcon: String {
        if isScanPending { return "hourglass" }
        return "sparkles"
    }

    private var scanButtonTint: Color {
        if isScanning { return .purple }
        if isScanPending { return .gray }
        return .blue
    }
}
