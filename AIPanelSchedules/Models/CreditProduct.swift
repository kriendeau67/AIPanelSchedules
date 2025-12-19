//
//  CreditProduct.swift
//  AIPanelSchedules
//
//  Created by Kenneth Riendeau on 12/19/25.
//

import Foundation

struct CreditProduct: Identifiable {
    let id: String            // StoreKit product ID later
    let credits: Int
    let title: String
    let subtitle: String
    var priceText: String     // Placeholder for now
}
