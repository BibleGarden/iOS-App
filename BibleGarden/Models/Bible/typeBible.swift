// Required types for working with the Bible via the API

import Foundation

// MARK: Verse structures

// Full verse version with chapter and book references
struct BibleTextualVerseFull: Hashable {
    let number: Int
    let html: String
    var join: Int = 0
    
    // To position book and chapter selection correctly
    var bookDigitCode: Int = 0
    var chapterDigitCode: Int = 0
     
    var skippedVerses = false
    
    var startParagraph = false
    
    var notes: [BibleNote] = []
    
    var beforeTitles: [BibleTitle] = []
    
}

struct BibleTitle: Hashable, Codable {
    let id: Int
    let text: String
    let metadata: String?
    let reference: String?
    var notes: [BibleNote] = []
    var subtitle: Bool = false
    var positionText: Int? = nil
    var positionHtml: Int? = nil
}

struct BibleNote: Hashable, Codable {
    let id: Int
    let text: String
    let positionHtml: Int
}

struct BibleAcousticalVerseFull: Hashable {
    let number: Int
    let text: String
    let begin: Double
    let end: Double
    var join: Int = 0
}

