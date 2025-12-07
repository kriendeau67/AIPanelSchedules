//
//  PanelDetailView.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/7/25.
//

import SwiftUI

struct PanelDetailView: View {
    let panel: Panel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(panel.name)
                    .font(.largeTitle)
                    .bold()

                Group {
                    infoRow(label: "Location", value: panel.location)
                    infoRow(label: "Voltage", value: panel.voltage)
                    infoRow(label: "Phases", value: panel.phases)
                    infoRow(label: "Mains", value: panel.mains)
                }

                Divider().padding(.vertical)

                Text("Circuits")
                    .font(.title2)
                    .bold()

                tableHeader

                ForEach(panel.circuits, id: \.id) { circuit in
                    tableRow(circuit)
                }
            }
            .padding()
        }
        .navigationTitle(panel.name)
    }

    @ViewBuilder
    func infoRow(label: String, value: String?) -> some View {
        if let value = value {
            HStack {
                Text(label + ":")
                    .bold()
                Spacer()
                Text(value)
            }
        }
    }

    var tableHeader: some View {
        HStack {
            Text("#").frame(width: 30, alignment: .leading).bold()
            Text("Description").frame(maxWidth: .infinity, alignment: .leading).bold()
            Text("Trip").frame(width: 50, alignment: .center).bold()
            Text("Poles").frame(width: 50, alignment: .center).bold()
        }
        .padding(.vertical, 4)
    }

    func tableRow(_ c: Circuit) -> some View {
        HStack {
            Text("\(c.number)").frame(width: 30, alignment: .leading)

            // FIX: unwrap the optional description
            Text(c.description ?? "—")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(c.tripAmps != nil ? "\(c.tripAmps!)" : "-")
                .frame(width: 50)

          //  Text("\(c.poles ?? )")
         //       .frame(width: 50)
          //  Text(c.poles != nil ? "\(c.poles!)" : "-")
            Text(c.poles.map { "\($0)" } ?? "-")
                .frame(width: 50)
        }
        .padding(.vertical, 2)
        .background(Color(.systemGray6))
        .cornerRadius(4)
    }
}
