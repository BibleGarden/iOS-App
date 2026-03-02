import SwiftUI

// MARK: Ready-made display

@ViewBuilder func viewExcerpt(verses: [BibleTextualVerseFull], fontIncreasePercent: Double, selectedId: Int=0) -> some View {
    
    let formattedText = verses.reduce(Text("")) { partialResult, verse in
        partialResult
        +
        Text("\(verse.number). ") // Verse number
            .font(.system(size: 7 * (1 + fontIncreasePercent / 100)))
            .foregroundColor(.white.opacity(0.5))
            //.id("verse_number_\(verse.id)")
        +
        Text(verse.html) // Verse text
            .foregroundColor(selectedId == verse.number ? Color("DarkGreen-accent") : .white)
            .font(.system(size: 10 * (1 + fontIncreasePercent / 100)))
        +
        Text(" ")
    }

    VStack {
        formattedText
            .lineSpacing(10.0)
    }
}

func getCSSColor(named colorName: String) -> String {
    if let selectedUIColor = UIColor(named: colorName) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if selectedUIColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return String(format: "rgba(%d, %d, %d, %.2f)", Int(red * 255), Int(green * 255), Int(blue * 255), alpha)
        }
    }
    return "yellow" // Default value
}


func generateHTMLContent(verses: [BibleTextualVerseFull], fontIncreasePercent: Double) -> String {
    let fontSize = 10 * (1 + fontIncreasePercent / 100)
    let selectedColor = getCSSColor(named: "DarkGreen-accent")
    let jesusColor = getCSSColor(named: "Jesus")
    let jesusSelectedColor = getCSSColor(named: "JesusSelected")
    //let jesusSelectedColor = getCSSColor(named: "Mustard")
    
    var htmlString = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                html {
                    font-size: \(fontSize)px; /* Base font size */
                    scroll-behavior: smooth;
                }

                body {
                    background-color: transparent;
                    color: #ffffff;
                    font-family: -apple-system, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                }

                h1 {
                    font-size: 1.3rem; 
                }

                p {
                    margin-bottom: 1rem;
                    font-size: 1rem; 
                }

                .verse-number {
                    font-size: 0.7rem; 
                    color: gray;
                    margin-right: 0.3rem;
                }
                               
                .quote-container {
                    padding-left: 1.1rem;
                    margin-block-start: 0.15rem;
                    margin-block-end: 0;
    
                    display: flex;
                    flex-direction: column;
                }
                .quote {
                    display: block;
                    font-family: serif;
                    font-style: italic;
                }
                .quote-container .verse-number {
                    position: absolute;
                    left: 0.35rem;
                    margin-top: 0.1rem;
                }
                .paragraph {
                    padding-top: 1rem;
                    display: block;
                }
                .quote-container .paragraph {
                    margin-left: -1.1rem;
                }
                .quote-container .paragraph .quote {
                    margin-left: 1.1rem;
                }
    
                .jesus {
                    color: \(jesusColor);
                }
                .e {
                    opacity: 0.7;
                }
                .gray {
                    opacity: 0.5;
                }
                .highlighted-verse {
                    color: \(selectedColor);
                }
                .highlighted-verse .jesus {
                    color: \(jesusSelectedColor);
                }
                                
                .note-icon {
                    width: 20px;
                    height: 20px;
                    margin-left: -2px;
                    margin-right: 2px;
                    position: relative;
                    top: 2px;
                    background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTkiIGhlaWdodD0iMTkiIHZpZXdCb3g9IjAgMCAxOSAxOSIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEzLjUgMUg1QzMuOTM5MTMgMSAyLjkyMTcyIDEuNDIxNDMgMi4xNzE1NyAyLjE3MTU3QzEuNDIxNDMgMi45MjE3MiAxIDMuOTM5MTMgMSA1VjEzLjVDMSAxNC41NjA5IDEuNDIxNDMgMTUuNTc4MyAyLjE3MTU3IDE2LjMyODRDMi45MjE3MiAxNy4wNzg2IDMuOTM5MTMgMTcuNSA1IDE3LjVIMTEuODQzQzEyLjM2ODQgMTcuNSAxMi44ODg3IDE3LjM5NjUgMTMuMzc0MSAxNy4xOTU0QzEzLjg1OTUgMTYuOTk0MyAxNC4zMDA1IDE2LjY5OTYgMTQuNjcyIDE2LjMyOEwxNi4zMjggMTQuNjcyQzE2LjY5OTYgMTQuMzAwNSAxNi45OTQzIDEzLjg1OTUgMTcuMTk1NCAxMy4zNzQxQzE3LjM5NjUgMTIuODg4NyAxNy41IDEyLjM2ODQgMTcuNSAxMS44NDNWNUMxNy41IDMuOTM5MTMgMTcuMDc4NiAyLjkyMTcyIDE2LjMyODQgMi4xNzE1N0MxNS41NzgzIDEuNDIxNDMgMTQuNTYwOSAxIDEzLjUgMVoiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iMS41IiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz4KPHBhdGggZD0iTTE3LjUgMTFIMTRDMTMuMjA0NCAxMSAxMi40NDEzIDExLjMxNjEgMTEuODc4NyAxMS44Nzg3QzExLjMxNjEgMTIuNDQxMyAxMSAxMy4yMDQ0IDExIDE0VjE3LjVNNSA1SDEyLjVNNSA5SDEwIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjEuNSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+Cjwvc3ZnPg==");
                    background-repeat: no-repeat;
                    background-size: contain;
                    background-position: center;
                    display: inline-block;
                    opacity: 0.5;
                }
                .note-text {
                    background-color: rgba(255,255,0,0.2);
                    display: block;
                    padding: 0 0.3rem;
                    margin: 0.2rem 0;
                    border-radius: 0.3rem;
                }
                .off {
                    display: none!important;
                }
    
                .title {
                    font-size: x-large;
                    font-weight: bold;
                }
                                
                /* comment for BSB, Song 1
                .subtitle:first-of-type {
                    display: inline;
                    text-align: center;
                }*/
                .subtitle {
                    font-size: 0.9rem;
                    color: rgba(255, 255, 255, 0.7);
                    margin-top: 0.8rem;
                    margin-bottom: 0.8rem;
                    display: block;
                    text-align: center;
                    font-weight: bold;
                }
                .metadata {
                    color: rgba(255, 255, 255, 0.7);
                    font-style: italic;
                }
                
                .reference {
                    font-size: 0.7rem;
                    font-weight: bold;
                    color: rgba(255, 255, 255, 0.8);
                    margin-top: -1rem;
                    margin-bottom: 1rem;
                }
    
                /* table nlt numbers 1 */
                .table {
                    width: 100%;
                    margin-top: 1rem;
                }
                .row {
                    display: flex;
                    border: 1px solid gray;
                    border-bottom: none;
                }
                .row:last-child {
                    border-bottom: 1px solid gray;
                }
                .left, .right {
                    padding: 2px;
                    box-sizing: border-box;
                    font-size: smaller; 
                }
                .left {
                    width: 35%;
                    border-right: 1px solid gray;
                }
                .right {
                    width: 65%;
                }
                .th {
                    font-weight: bold!important;
                    background-color: rgba(122, 122, 122, 0.2);
                }
            </style>
        </head>
        <body>
    """

    for verse in verses {
        // Separate regular titles and subtitles
        let regularTitles = verse.beforeTitles.filter { !$0.subtitle }
        // Subtitles with position 0 go before the verse text
        let subtitlesAtStart = verse.beforeTitles.filter { $0.subtitle && ($0.positionHtml ?? 0) == 0 }

        // Regular titles (displayed before the verse)
        for title in regularTitles {
            var titleHTML = title.text
            let hasMetadata = title.metadata != nil && !title.metadata!.isEmpty

            // If title has notes but no metadata, insert note icons at the end of the title text
            if !title.notes.isEmpty && !hasMetadata {
                for note in title.notes {
                    let noteHTML = """
                        <span class="note">
                            <span class="note-icon" onClick="document.getElementById('note\(note.id)').classList.toggle('off');"></span>
                            <span class="note-text off" id="note\(note.id)">\(note.text)</span>
                        </span>
                    """
                    titleHTML += noteHTML
                }
            }

            htmlString += """
                <div id="top"></div>
                <p id="title-\(title.id)" class="title">\(titleHTML)</p>
            """

            // reference
            if let reference = title.reference, !reference.isEmpty {
                htmlString += """
                    <p class="reference">\(reference)</p>
                """
            }

            // Subtitle metadata
            if hasMetadata {
                // Insert notes into metadata
                var metadataHTML = title.metadata!
                var prevNotesOffset = 0
                // Sort notes by position_html for proper insertion
                let sortedNotes = title.notes.sorted { $0.positionHtml < $1.positionHtml }
                for note in sortedNotes {
                    let noteHTML = """
                        <span class="note">
                            <span class="note-icon" onClick="document.getElementById('note\(note.id)').classList.toggle('off');"></span>
                            <span class="note-text off" id="note\(note.id)">\(note.text)</span>
                        </span>
                    """
                    metadataHTML = insertSubstring(original: metadataHTML, substring: noteHTML, at: prevNotesOffset+note.positionHtml)
                    prevNotesOffset += noteHTML.count
                }

                htmlString += """
                    <p class="subtitle">\(metadataHTML)</p>
                """
            }
        }

        // Subtitles at position 0 - display before verse text
        for subtitle in subtitlesAtStart {
            var subtitleHTML = subtitle.text
            if !subtitle.notes.isEmpty {
                for note in subtitle.notes {
                    subtitleHTML += """
                        <span class="note">
                            <span class="note-icon" onClick="document.getElementById('note\(note.id)').classList.toggle('off');"></span>
                            <span class="note-text off" id="note\(note.id)">\(note.text)</span>
                        </span>
                    """
                }
            }
            htmlString += """
                <span class="subtitle">\(subtitleHTML)</span>
            """
        }

        // Insert notes and inline subtitles into verse HTML
        // Combine notes and subtitles into a single list with position and type
        var verseHTML = verse.html
        var insertions: [(position: Int, isNote: Bool, html: String)] = []

        // Add notes
        for note in verse.notes {
            let noteHTML = """
                <span class="note">
                    <span class="note-icon" onClick="document.getElementById('note\(note.id)').classList.toggle('off');"></span>
                    <span class="note-text off" id="note\(note.id)">\(note.text)</span>
                </span>
            """
            insertions.append((position: note.positionHtml, isNote: true, html: noteHTML))
        }

        // Add inline subtitles (position > 0)
        let subtitlesInline = verse.beforeTitles.filter { $0.subtitle && ($0.positionHtml ?? 0) > 0 }
        for subtitle in subtitlesInline {
            let subtitleHTML = """
                <span class="subtitle">\(subtitle.text)</span>
            """
            insertions.append((position: subtitle.positionHtml ?? 0, isNote: false, html: subtitleHTML))
        }

        // Sort by position ascending, notes before subtitles when same position
        insertions.sort { a, b in
            if a.position != b.position {
                return a.position < b.position
            }
            // Same position: notes come before subtitles
            return a.isNote && !b.isNote
        }

        // Insert in order, tracking offset
        var offset = 0
        for insertion in insertions {
            verseHTML = insertSubstring(original: verseHTML, substring: insertion.html, at: offset + insertion.position)
            offset += insertion.html.count
        }

        // Paragraphs
        let id_info = verse.join > 0 ? "\(verse.number)-\(verse.number+verse.join)" : "\(verse.number)"

        let quoteContainer = verse.html.contains("class=\"quote\"") ? "quote-container" : ""
        if verse.startParagraph {
            htmlString += "<p>"
        }
        htmlString += """
            <span id="verse-\(verse.number)" class="\(quoteContainer)"><span class="verse-number">\(id_info).</span><span>\(verseHTML)</span></span>
        """
    }

    htmlString += """
        </body>
        </html>
    """
    
    //print(htmlString)
    
    return htmlString
}

func insertSubstring(original: String, substring: String, at position: Int) -> String {
    guard position >= 0 && position <= original.count else {
        print("Invalid position.")
        return original
    }
    
    let index = original.index(original.startIndex, offsetBy: position)
    let newString = original.prefix(upTo: index) + substring + String(original.suffix(from: index))
    return String(newString)
}
