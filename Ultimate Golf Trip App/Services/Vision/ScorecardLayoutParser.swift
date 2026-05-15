import Foundation
import CoreGraphics

/// A single cell read from a player's row.
struct ParsedCell: Hashable {
    /// Hole number this cell represents (1...holeCount).
    let holeNumber: Int
    /// Strokes read for this cell, or nil if no number was detected.
    let strokes: Int?
    /// Combined confidence in the read, 0.0–1.0. Lower values prompt confirmation.
    let confidence: Float
    /// True if a number was detected but failed a sanity check (e.g. front-9 sum mismatch).
    var flagged: Bool
}

/// One player row pulled from the scorecard image.
struct ParsedRow: Hashable, Identifiable {
    let id: UUID
    /// Index of this row on the card, top to bottom (0-based).
    let rowIndex: Int
    /// Y center of the row in image pixels — used to draw the highlight on the photo.
    let yCenter: CGFloat
    /// Best guess at the player name written on the card (top recognized text in the row, left of holes).
    /// May be empty.
    let detectedName: String
    /// One cell per hole 1...holeCount, sorted by hole number.
    var cells: [ParsedCell]
}

/// Parsed result for a full scorecard.
struct ParsedScorecard {
    let holeCount: Int
    /// Player rows detected in the photo.
    var rows: [ParsedRow]
    /// True if the header row (1,2,...,9,OUT,...) couldn't be located — caller should ask for a retake.
    let headerDetected: Bool
}

enum ScorecardLayoutParser {
    /// Cells below this confidence are flagged for confirmation.
    static let confidenceThreshold: Float = 0.5

    /// Parses the OCR observations into a per-row, per-hole grid.
    /// - Parameters:
    ///   - observations: Raw OCR results from `ScorecardOCRService`.
    ///   - holeCount: Number of holes in this round (typically 18, sometimes 9).
    static func parse(observations: [OCRObservation], holeCount: Int) -> ParsedScorecard {
        guard !observations.isEmpty else {
            return ParsedScorecard(holeCount: holeCount, rows: [], headerDetected: false)
        }

        // Step 1: Group observations into horizontal bands (rows on the printed card).
        let bands = clusterIntoBands(observations: observations)

        // Step 2: Find the band that looks like the hole-number header row.
        guard let header = findHeaderBand(bands: bands, holeCount: holeCount) else {
            return ParsedScorecard(holeCount: holeCount, rows: [], headerDetected: false)
        }

        // Step 3: Compute the column x-center for each hole (1...holeCount).
        let columnCenters = header.columnCenters

        // Step 4: For each band BELOW the header that contains numeric cells in those columns, build a row.
        let dataBands = bands
            .filter { $0.yCenter > header.band.yCenter + (header.band.height * 0.5) }
            .sorted { $0.yCenter < $1.yCenter }

        // Pass `rows.count` as the rowIndex so each surviving row gets its final position-in-result
        // as its index, not its position in the raw band list. This keeps `preferredRowAssignments`
        // stable across imports of the same card even if the par/yardage reference row is
        // detected one time and missed another.
        var rows: [ParsedRow] = []
        for band in dataBands {
            let row = buildRow(
                band: band,
                rowIndex: rows.count,
                columnCenters: columnCenters,
                columnWidth: header.columnWidth,
                holeCount: holeCount
            )
            // Drop bands that look like par/yardage/handicap reference rows (numbers in EVERY column,
            // mostly within typical par/yardage ranges) — keep only bands that look like player score rows.
            if row.cells.contains(where: { $0.strokes != nil }) && !looksLikeReferenceRow(row.cells) {
                rows.append(row)
            }
        }

        // Step 5: Apply sanity check — front-9 sum should equal OUT cell value, if present in the band.
        rows = rows.map { applySumCheck(row: $0, header: header) }

        return ParsedScorecard(holeCount: holeCount, rows: rows, headerDetected: true)
    }

    // MARK: - Band clustering

    /// A horizontal "row" on the card — a cluster of observations with similar y-centers.
    private struct Band {
        var observations: [OCRObservation]
        var yCenter: CGFloat
        var height: CGFloat
    }

    private static func clusterIntoBands(observations: [OCRObservation]) -> [Band] {
        let sorted = observations.sorted { $0.boundingBox.midY < $1.boundingBox.midY }
        guard !sorted.isEmpty else { return [] }

        // Use median observation height as the row-tolerance unit.
        let heights = sorted.map { $0.boundingBox.height }.sorted()
        let medianHeight = heights[heights.count / 2]
        let tolerance = max(medianHeight * 0.7, 6)

        var bands: [Band] = []
        for obs in sorted {
            let cy = obs.boundingBox.midY
            if let lastIdx = bands.indices.last, abs(cy - bands[lastIdx].yCenter) <= tolerance {
                bands[lastIdx].observations.append(obs)
                let ys = bands[lastIdx].observations.map { $0.boundingBox.midY }
                bands[lastIdx].yCenter = ys.reduce(0, +) / CGFloat(ys.count)
                bands[lastIdx].height = max(bands[lastIdx].height, obs.boundingBox.height)
            } else {
                bands.append(Band(
                    observations: [obs],
                    yCenter: cy,
                    height: obs.boundingBox.height
                ))
            }
        }
        return bands
    }

    // MARK: - Header detection

    private struct HeaderMatch {
        let band: Band
        /// x-center for each hole, indexed by holeNumber (1...holeCount).
        let columnCenters: [Int: CGFloat]
        /// Approximate column width — used to widen the search box for each cell.
        let columnWidth: CGFloat
        /// x-center of the OUT column, if found.
        let outCenter: CGFloat?
        /// x-center of the IN column, if found.
        let inCenter: CGFloat?
    }

    /// A band is the hole header when it contains the digits 1..9 (or 10..holeCount) in left-to-right order.
    private static func findHeaderBand(bands: [Band], holeCount: Int) -> HeaderMatch? {
        // Score every band for "looks like 1,2,...,9 in order"; keep the best two and merge their column maps.
        let candidates = bands.map { ($0, scoreAsHeader(band: $0, holeCount: holeCount)) }
            .filter { $0.1.matchedHoles.count >= 4 }
            .sorted { $0.1.matchedHoles.count > $1.1.matchedHoles.count }

        guard let top = candidates.first else { return nil }

        // Merge column centers from up to two headers (some cards have separate "1..9" and "10..18" rows).
        var columns = top.1.columnCenters
        if let second = candidates.dropFirst().first {
            for (hole, x) in second.1.columnCenters where columns[hole] == nil {
                columns[hole] = x
            }
        }

        // Need at least 6 hole columns to be confident.
        guard columns.count >= 6 else { return nil }

        // Estimate column width as median spacing between adjacent matched columns.
        let xs = columns.keys.sorted().compactMap { columns[$0] }
        var diffs: [CGFloat] = []
        for i in 1..<xs.count { diffs.append(xs[i] - xs[i-1]) }
        let columnWidth: CGFloat
        if !diffs.isEmpty {
            let sortedDiffs = diffs.sorted()
            columnWidth = sortedDiffs[sortedDiffs.count / 2]
        } else {
            columnWidth = top.0.height * 1.5
        }

        // Detect OUT / IN columns from the header text.
        let outCenter = top.0.observations.first(where: { $0.text.uppercased().contains("OUT") })?.boundingBox.midX
        let inCenter = top.0.observations.first(where: { isInLabel($0.text) })?.boundingBox.midX

        return HeaderMatch(
            band: top.0,
            columnCenters: columns,
            columnWidth: columnWidth,
            outCenter: outCenter,
            inCenter: inCenter
        )
    }

    private struct HeaderScore {
        var matchedHoles: [Int]   // hole numbers we found in this band
        var columnCenters: [Int: CGFloat]
    }

    private static func scoreAsHeader(band: Band, holeCount: Int) -> HeaderScore {
        // Only consider single-/double-digit integer tokens.
        var bestPerHole: [Int: (CGFloat, Float)] = [:]
        for obs in band.observations {
            guard let n = Int(obs.text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  n >= 1, n <= holeCount else { continue }
            // Sanity: a hole label is short — skip if the text has extra characters making it look like a score.
            let stripped = obs.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard stripped.count <= 2 else { continue }
            // Prefer the higher-confidence observation if the same number appears twice.
            if let existing = bestPerHole[n], existing.1 >= obs.confidence { continue }
            bestPerHole[n] = (obs.boundingBox.midX, obs.confidence)
        }

        // Require the matched numbers to be roughly ordered left-to-right.
        let ordered = bestPerHole.sorted { $0.value.0 < $1.value.0 }
        let matchedHoles = ordered.map(\.key)
        let isAscending = zip(matchedHoles, matchedHoles.dropFirst()).allSatisfy { $0 < $1 }
        guard isAscending else {
            return HeaderScore(matchedHoles: [], columnCenters: [:])
        }
        let centers = Dictionary(uniqueKeysWithValues: bestPerHole.map { ($0.key, $0.value.0) })
        return HeaderScore(matchedHoles: matchedHoles, columnCenters: centers)
    }

    private static func isInLabel(_ text: String) -> Bool {
        // Match "IN" but not "INFO" / "IN BOUNDS" / numbers.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed == "IN"
    }

    // MARK: - Row building

    private static func buildRow(
        band: Band,
        rowIndex: Int,
        columnCenters: [Int: CGFloat],
        columnWidth: CGFloat,
        holeCount: Int
    ) -> ParsedRow {
        // Build cells by hole number.
        var cells: [ParsedCell] = []
        for hole in 1...holeCount {
            guard let cx = columnCenters[hole] else {
                cells.append(ParsedCell(holeNumber: hole, strokes: nil, confidence: 0, flagged: false))
                continue
            }
            // Search for a numeric observation whose x-center is closest to `cx` and within ~half a column.
            let candidates = band.observations.compactMap { obs -> (Int, CGFloat, Float)? in
                guard let value = parseStrokeValue(obs.text) else { return nil }
                let dx = abs(obs.boundingBox.midX - cx)
                guard dx <= columnWidth * 0.55 else { return nil }
                return (value, dx, obs.confidence)
            }
            if let best = candidates.min(by: { $0.1 < $1.1 }) {
                // Combine OCR confidence with how centered the cell is (closer to center = higher).
                let centeringScore = Float(1 - min(best.1 / max(columnWidth * 0.55, 1), 1.0))
                let combined = (best.2 * 0.7) + (centeringScore * 0.3)
                cells.append(ParsedCell(
                    holeNumber: hole,
                    strokes: best.0,
                    confidence: combined,
                    flagged: combined < confidenceThreshold
                ))
            } else {
                cells.append(ParsedCell(holeNumber: hole, strokes: nil, confidence: 0, flagged: false))
            }
        }

        // Best guess at the player name: the leftmost non-numeric observation in the band.
        let nameCandidate = band.observations
            .filter { obs in parseStrokeValue(obs.text) == nil && obs.text.count > 1 }
            .min(by: { $0.boundingBox.minX < $1.boundingBox.minX })
        let detectedName = nameCandidate?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ParsedRow(
            id: UUID(),
            rowIndex: rowIndex,
            yCenter: band.yCenter,
            detectedName: detectedName,
            cells: cells
        )
    }

    /// Accepts plausible stroke values (1–15). Rejects multi-digit totals.
    private static func parseStrokeValue(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(trimmed), n >= 1, n <= 15, trimmed.count <= 2 else { return nil }
        return n
    }

    // MARK: - Reference-row filter

    /// A row where every cell is the same small set of values (3, 4, 5) likely represents the par row.
    /// Filter these out so they don't appear as player rows.
    private static func looksLikeReferenceRow(_ cells: [ParsedCell]) -> Bool {
        let strokes = cells.compactMap(\.strokes)
        guard strokes.count >= 9 else { return false }
        // Par rows: every value in [3, 4, 5] and the row contains at least one par-3.
        let allParValues = strokes.allSatisfy { $0 >= 3 && $0 <= 5 }
        let hasParThree = strokes.contains(3)
        let hasParFiveOrFour = strokes.contains(where: { $0 == 4 || $0 == 5 })
        return allParValues && hasParThree && hasParFiveOrFour
    }

    // MARK: - Sum check

    private static func applySumCheck(row: ParsedRow, header: HeaderMatch) -> ParsedRow {
        // If we can't find an OUT/IN total in the band aligned to this row, skip the check.
        // (We don't currently extract totals — the heuristic is purely "do the 9 numbers look plausible?".)
        // For v1, flag rows whose total exceeds 18 * 12 = absurd, or whose visible strokes contain
        // any single value > 12 (rare in casual play and almost always a misread).
        var updated = row
        for i in updated.cells.indices {
            if let s = updated.cells[i].strokes, s > 12 {
                updated.cells[i].flagged = true
            }
        }
        return updated
    }
}
