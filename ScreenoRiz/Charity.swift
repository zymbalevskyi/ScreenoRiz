//
//  Charity.swift
//  ScreenoRiz
//

import Foundation

struct Charity: Identifiable, Codable {
    let id: String
    let name: String
    let fundName: String
    let jarType: String   // "gather" | "fund"
    let url: String
    let coverAsset: String
    let logoAsset: String

    /// "БФ Хартія створив збір" for gather, plain fundName for fund
    var fundLabel: String {
        jarType == "gather" ? "\(fundName) створив збір" : fundName
    }

    static let all: [Charity] = {
        guard
            let fileURL = Bundle.main.url(forResource: "jars", withExtension: "json"),
            let data    = try? Data(contentsOf: fileURL),
            let jars    = try? JSONDecoder().decode([Charity].self, from: data)
        else { return [] }
        return jars
    }()
}
