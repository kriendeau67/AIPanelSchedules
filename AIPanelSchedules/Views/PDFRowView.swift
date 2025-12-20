import SwiftUI

struct PDFRowView: View {
    let fileName: String
    let hasBeenScanned: Bool
    let isScanning: Bool
    let isScanPending: Bool
    let isGeneratingExcel: Bool   // 👈 RIGHT HERE
    let scanStatusText: String
    let finalExcelURL: URL?
    let excelLocked: Bool
    let onExcelTap: () -> Void
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

                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Preparing Excel")
                                    .font(.headline)

                                Text("This may take a moment…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    } else if let url = finalExcelURL {

                        Button {
                            onExcelTap()
                        } label: {
                            Label {
                                Text(excelLocked ? "Unlock Excel" : "Open Excel")
                                    .frame(minWidth: 110, alignment: .leading)
                            } icon: {
                                Image(systemName: excelLocked ? "lock.fill" : "tablecells")
                                    .frame(width: 20)
                            }
                        }
                        .tint(excelLocked ? .red : .green)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete PDF", systemImage: "trash")
            }
        }
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
