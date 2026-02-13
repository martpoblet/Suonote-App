import SwiftUI
import PDFKit

/// Generates a PDF chord chart from a project (P-10)
struct ChordChartPDFGenerator {
    
    static func generatePDF(for project: Project) -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - 2 * margin
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin
            
            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let title = project.title
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36
            
            // Metadata line
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let meta = "Key: \(project.keyRoot) \(project.keyMode.rawValue)  |  BPM: \(project.bpm)  |  Time: \(project.timeTop)/\(project.timeBottom)"
            meta.draw(at: CGPoint(x: margin, y: y), withAttributes: metaAttrs)
            y += 24
            
            // Separator
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: margin, y: y))
            separatorPath.addLine(to: CGPoint(x: margin + contentWidth, y: y))
            UIColor.gray.setStroke()
            separatorPath.lineWidth = 0.5
            separatorPath.stroke()
            y += 16
            
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let chordAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            let lyricsAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]
            
            for section in project.sectionTemplates {
                // Check if we need a new page
                if y > pageHeight - 120 {
                    context.beginPage()
                    y = margin
                }
                
                // Section name
                let sectionLabel = section.hasKeyChange
                    ? "\(section.name)  [\(section.effectiveKeyRoot) \(section.effectiveKeyMode.rawValue)]"
                    : section.name
                sectionLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttrs)
                y += 24
                
                // Chords in a grid (4 per line)
                let chords = section.chordEvents
                let chordsPerLine = 4
                let cellWidth = contentWidth / CGFloat(chordsPerLine)
                
                for (idx, chord) in chords.enumerated() {
                    let col = idx % chordsPerLine
                    let x = margin + CGFloat(col) * cellWidth
                    
                    if col == 0 && idx > 0 {
                        y += 22
                        if y > pageHeight - 80 {
                            context.beginPage()
                            y = margin
                        }
                    }
                    
                    let display = chord.display
                    // Draw bar line
                    if col == 0 {
                        let barPath = UIBezierPath()
                        barPath.move(to: CGPoint(x: margin, y: y - 2))
                        barPath.addLine(to: CGPoint(x: margin, y: y + 18))
                        UIColor.lightGray.setStroke()
                        barPath.lineWidth = 1
                        barPath.stroke()
                    }
                    
                    display.draw(at: CGPoint(x: x + 8, y: y), withAttributes: chordAttrs)
                }
                y += 28
                
                // Lyrics (if any)
                if !section.lyricsText.isEmpty {
                    let lyricsRect = CGRect(x: margin, y: y, width: contentWidth, height: 60)
                    let trimmed = String(section.lyricsText.prefix(300))
                    trimmed.draw(in: lyricsRect, withAttributes: lyricsAttrs)
                    y += 44
                }
                
                y += 12
            }
            
            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.lightGray
            ]
            let footer = "Generated by Suonote"
            footer.draw(at: CGPoint(x: margin, y: pageHeight - 30), withAttributes: footerAttrs)
        }
    }
}
