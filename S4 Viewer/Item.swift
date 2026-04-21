//
//  Item.swift
//  S4 Viewer
//
//  Created by 森拓海 on 2026-04-21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
