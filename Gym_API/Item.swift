//
//  Item.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
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
