import SwiftUI
import OpenAPIURLSession

// MARK: Online API

func getExcerptTextualVersesOnline(excerpts: String, client: APIProtocol, translation: Int, voice: Int) async throws -> ([BibleTextualVerseFull], [BibleAcousticalVerseFull], String, Bool, Components.Schemas.PartsWithAlignmentModel?) {
    do {
        let response = try await client.get_excerpt_with_alignment(query: .init(translation: translation, excerpt: excerpts, voice: voice))
        
        if let unprocessableContent = try? response.unprocessableContent {
            let detail = try unprocessableContent.body.json.detail
            throw NSError(domain: "getExcerptTextualVersesOnline", code: 422, userInfo: [NSLocalizedDescriptionKey: detail])
        }
        
        let answer = try response.ok.body.json
        let parts = answer.parts
        
        var resTextVerses: [BibleTextualVerseFull] = []
        var resAudioVerses: [BibleAcousticalVerseFull] = []
        var resFirstUrl: String = ""
        var resPart: Components.Schemas.PartsWithAlignmentModel?
        let resSingleChapter = answer.is_single_chapter
        
        var oldVerse: Int = 0
        
        for part in parts {
            if resFirstUrl == "" { resFirstUrl = part.audio_link }
            resPart = part

            for verse in part.verses {
                var verseFull = BibleTextualVerseFull(
                    number: verse.number,
                    html: verse.html,
                    join: verse.join,
                    bookDigitCode: part.book.number,
                    chapterDigitCode: part.chapter_number,
                    skippedVerses: !(verse.number - oldVerse == 1 || oldVerse == 0),
                    startParagraph: verse.start_paragraph
                )
                for note in part.notes {
                    if note.verse_code == verse.code {
                        verseFull.notes.append(BibleNote(id: note.code, text: note.text, positionHtml: note.position_html))
                    }
                }
                for title in part.titles {
                    if title.before_verse_code == verse.code {
                        var titleWithNotes = BibleTitle(
                            id: title.code,
                            text: title.text,
                            metadata: title.metadata,
                            reference: title.reference,
                            subtitle: title.subtitle ?? false,
                            positionText: title.position_text,
                            positionHtml: title.position_html
                        )

                        // Add notes to the title
                        for note in part.notes {
                            if note.title_code == title.code {
                                titleWithNotes.notes.append(BibleNote(id: note.code, text: note.text, positionHtml: note.position_html))
                            }
                        }

                        verseFull.beforeTitles.append(titleWithNotes)
                    }
                }
                resTextVerses.append(verseFull)
                
                resAudioVerses.append(BibleAcousticalVerseFull(
                    number: verse.number,
                    text: verse.text,
                    begin: verse.begin,
                    end: verse.end,
                    join: verse.join
                ))
                oldVerse = verse.number
            }
        }
        
        // Sort verses based on join property
        // We use a stable sort to preserve relative order of verses with the same target position
        // The sort key is (verse.number + verse.join)
        let sortClosure: (Int, Int, Int, Int) -> Bool = { (num1, join1, num2, join2) in
            let pos1 = num1 + join1
            let pos2 = num2 + join2
            
            if pos1 != pos2 {
                return pos1 < pos2
            }
            return num1 < num2
        }
        
        resTextVerses.sort { sortClosure($0.number, $0.join, $1.number, $1.join) }
        resAudioVerses.sort { sortClosure($0.number, $0.join, $1.number, $1.join) }
        
        // Ensure the first audio URL includes the api_key as a query parameter
        var firstURLWithKey = resFirstUrl
        if let original = URL(string: resFirstUrl) {
            let withKey = SettingsManager.audioURLWithKey(from: original)
            firstURLWithKey = withKey.absoluteString
        }
        return (resTextVerses, resAudioVerses, firstURLWithKey, resSingleChapter, resPart)
    } catch {
        
        throw error
    }
}

// MARK: Utility functions

// Start and end of the excerpt in the current narration
func getExcerptPeriod(audioVerses: [BibleAcousticalVerseFull]) -> (Double, Double) {
    
    guard audioVerses.count > 0 else {
        return (0, 0)
    }
    
    let period_from: Double = audioVerses[0].begin
    let period_to: Double = audioVerses[audioVerses.count - 1].end
    
    return (period_from, period_to)
}
