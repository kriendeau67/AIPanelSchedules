import SwiftUI

struct PanelListView: View {
    let panels: [Panel]

    var body: some View {
        List {
            // Summary
            Section {
                Text("\(panels.count) Panels Extracted")
                    .font(.headline)
            }

            // Panels
            Section("Panels") {
                ForEach(panels) { panel in
                    VStack(alignment: .leading, spacing: 6) {

                        // Panel Name
                        Text(panel.name)
                            .font(.headline)

                        // Optional metadata row
                        VStack(alignment: .leading, spacing: 2) {

                            if let location = panel.location, !location.isEmpty {
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 12) {
                                if let voltage = panel.voltage, !voltage.isEmpty {
                                    Text(voltage)
                                }

                                if let phases = panel.phases, !phases.isEmpty {
                                    Text(phases)
                                }

                                if let mains = panel.mains, !mains.isEmpty {
                                    Text(mains)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        // Circuit count (confidence builder)
                        Text("\(panel.circuits.count) circuits detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Extracted Panels")
        .navigationBarTitleDisplayMode(.inline)
    }
}
