import SwiftUI

// MARK: Constants
protocol DisplayNameProvider {
    var displayName: String { get }
}
enum PauseType: String, CaseIterable, Identifiable, DisplayNameProvider {
    case none
    case time
    case full
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
            case .none: return "settings.pause.type.none".localized
            case .time: return "settings.pause.type.time".localized
            case .full: return "settings.pause.type.full".localized
        }
    }
}

enum PauseBlock: String, CaseIterable, Identifiable, DisplayNameProvider {
    case verse
    case paragraph
    case fragment
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
            case .verse: return "settings.pause.block.verse".localized
            case .paragraph: return "settings.pause.block.paragraph".localized
            case .fragment: return "settings.pause.block.fragment".localized
        }
    }
    
    var shortName: String {
        switch self {
            case .verse: return "settings.pause.block.short.verse".localized
            case .paragraph: return "settings.pause.block.short.paragraph".localized
            case .fragment: return "settings.pause.block.short.fragment".localized
        }
    }
}

