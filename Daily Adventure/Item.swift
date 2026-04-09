//
//  Item.swift
//  Daily Adventure
//
//  Created by Vishal Bhogal on 09/04/26.
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
