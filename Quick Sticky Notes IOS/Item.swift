//
//  Item.swift
//  Quick Sticky Notes IOS
//
//  Created by Prakash Joshi on 13/01/2025.
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
