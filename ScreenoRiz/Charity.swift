//
//  Charity.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import Foundation

struct Charity: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: String
    
    static let all: [Charity] = [
        Charity(
            name: "Повернись живим",
            description: "Фонд допомоги українським військовим",
            url: "https://savelife.in.ua"
        ),
        Charity(
            name: "Янголи Азову",
            description: "Допомога бійцям Азову та їх родинам",
            url: "https://angelsofazov.org"
        ),
        Charity(
            name: "UA Animals",
            description: "Порятунок тварин під час війни",
            url: "https://uanimals.org"
        )
    ]
}
