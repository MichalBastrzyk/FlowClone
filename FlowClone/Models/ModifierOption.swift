//
//  ModifierOption.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation

/// Shared modifier option type used across hotkey settings and service
enum ModifierOption: CaseIterable, Hashable, Comparable {
    case shift
    case control
    case option
    case command
    case fn

    var displayName: String {
        switch self {
        case .shift: return "Shift"
        case .control: return "Control"
        case .option: return "Option"
        case .command: return "Command"
        case .fn: return "Fn"
        }
    }

    static func < (lhs: ModifierOption, rhs: ModifierOption) -> Bool {
        lhs.displayName < rhs.displayName
    }
}
