import SwiftUI

/// Shows the captured photo plus an editable grid of extracted scores.
/// Each row needs to be assigned to a trip player; flagged cells need confirmation before apply.
struct ScorecardReviewView: View {
    @Bindable var viewModel: ScorecardImportViewModel
    let onApply: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var editingCell: EditingCell?
    @State private var showOverwriteConfirm = false

    struct EditingCell: Identifiable {
        let rowId: UUID
        let holeNumber: Int
        var id: String { "\(rowId)#\(holeNumber)" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = viewModel.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 2))
                        .padding(.horizontal)
                }

                instructionsBanner

                if viewModel.hasPlayingGroups {
                    groupScopeBar
                }

                if let parsed = viewModel.parsed {
                    if parsed.rows.isEmpty {
                        emptyState
                    } else {
                        ForEach(parsed.rows) { row in
                            rowCard(row)
                        }
                    }
                }

                Color.clear.frame(height: 16)
            }
            .padding(.vertical)
        }
        .background(Theme.background)
        .navigationTitle("Review Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Retake", action: onRetake)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if viewModel.roundHasExistingScores {
                        showOverwriteConfirm = true
                    } else {
                        onApply()
                    }
                } label: {
                    Text("Apply")
                        .fontWeight(.semibold)
                }
                .disabled(viewModel.playerByRow.isEmpty)
            }
        }
        .sheet(item: $editingCell) { cell in
            CellEditorSheet(
                rowId: cell.rowId,
                holeNumber: cell.holeNumber,
                currentValue: viewModel.effectiveStrokes(rowId: cell.rowId, holeNumber: cell.holeNumber),
                onSave: { value in
                    viewModel.setOverride(rowId: cell.rowId, holeNumber: cell.holeNumber, value: value)
                    editingCell = nil
                },
                onClear: {
                    viewModel.setOverride(rowId: cell.rowId, holeNumber: cell.holeNumber, value: nil)
                    editingCell = nil
                }
            )
            .presentationDetents([.height(320)])
        }
        .confirmationDialog(
            "Replace existing scores?",
            isPresented: $showOverwriteConfirm,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive, action: onApply)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This round already has scores entered. Importing will overwrite them for the mapped players.")
        }
    }

    // MARK: - Subviews

    // MARK: - Group scope

    /// Horizontal chip bar shown when the round has playing groups. Narrows the player
    /// picker on every row to a single foursome so the user isn't paging through 12 names.
    private var groupScopeBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Importing for")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(0.5)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(title: "All players",
                         isSelected: viewModel.scopedGroupId == nil) {
                        viewModel.setScopedGroup(nil)
                    }
                    ForEach(viewModel.playingGroups) { group in
                        chip(title: group.name,
                             isSelected: viewModel.scopedGroupId == group.id) {
                            viewModel.setScopedGroup(group.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.primary : Theme.cardBackground)
                .foregroundStyle(isSelected ? Theme.textOnPrimary : Theme.textPrimary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var instructionsBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tap each row to assign a player. Yellow cells need confirmation.")
                    .font(.subheadline.weight(.semibold))
                Text("Tap any cell to edit. Scoring rules (handicap, match play, etc.) apply automatically when you tap Apply.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.primaryMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.warning)
            Text("No player rows detected")
                .font(.headline)
            Text("Try retaking the photo with the full scorecard visible, flat lighting, and minimal glare.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retake", action: onRetake)
                .buttonStyle(BoldPrimaryButtonStyle())
                .padding(.top, 4)
        }
        .padding()
        .padding(.horizontal)
    }

    @ViewBuilder
    private func rowCard(_ row: ParsedRow) -> some View {
        let assignedPlayerId = viewModel.playerByRow[row.id]
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                playerPicker(rowId: row.id, assignedPlayerId: assignedPlayerId, detectedName: row.detectedName)
                Spacer()
                rowTotal(row: row)
            }
            holesGrid(row: row, disabled: assignedPlayerId == nil)
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func playerPicker(rowId: UUID, assignedPlayerId: UUID?, detectedName: String) -> some View {
        Menu {
            Button("Ignore this row") {
                viewModel.assign(player: nil, toRow: rowId)
            }
            Divider()
            ForEach(viewModel.availablePlayers) { player in
                Button {
                    viewModel.assign(player: player.id, toRow: rowId)
                } label: {
                    if assignedPlayerId == player.id {
                        Label(player.name, systemImage: "checkmark")
                    } else {
                        Text(player.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Use the full round roster for the label lookup so out-of-scope assignments
                // still render their name (the user just can't pick a new one without widening scope).
                if let pid = assignedPlayerId,
                   let player = viewModel.allRoundPlayers.first(where: { $0.id == pid }) {
                    Circle()
                        .fill(player.avatarColor.color)
                        .frame(width: 28, height: 28)
                        .overlay(Text(player.initials).font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                    Text(player.name).font(.subheadline.weight(.semibold))
                } else {
                    Circle()
                        .fill(Theme.border)
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 12)).foregroundStyle(Theme.textSecondary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assign player")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        if !detectedName.isEmpty {
                            Text("Detected: \(detectedName)")
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func rowTotal(row: ParsedRow) -> some View {
        let total = (1...viewModel.holeCount).compactMap { viewModel.effectiveStrokes(rowId: row.id, holeNumber: $0) }.reduce(0, +)
        return VStack(alignment: .trailing, spacing: 2) {
            Text("\(total)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text("Total")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func holesGrid(row: ParsedRow, disabled: Bool) -> some View {
        let half = viewModel.holeCount / 2
        return VStack(spacing: 6) {
            holeRow(row: row, holes: Array(1...max(half, 1)), disabled: disabled)
            if viewModel.holeCount > half {
                holeRow(row: row, holes: Array((half + 1)...viewModel.holeCount), disabled: disabled)
            }
        }
    }

    private func holeRow(row: ParsedRow, holes: [Int], disabled: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(holes, id: \.self) { hole in
                cellButton(rowId: row.id, holeNumber: hole, disabled: disabled)
            }
        }
    }

    private func cellButton(rowId: UUID, holeNumber: Int, disabled: Bool) -> some View {
        let strokes = viewModel.effectiveStrokes(rowId: rowId, holeNumber: holeNumber)
        let flagged = viewModel.isCellFlagged(rowId: rowId, holeNumber: holeNumber)
        return Button {
            editingCell = EditingCell(rowId: rowId, holeNumber: holeNumber)
        } label: {
            VStack(spacing: 1) {
                Text("\(holeNumber)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(strokes.map(String.init) ?? "—")
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(strokes == nil ? Theme.textSecondary : Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(flagged ? Theme.warning.opacity(0.25) : Theme.background)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(flagged ? Theme.warning : Theme.border, lineWidth: flagged ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

// MARK: - Cell editor sheet

private struct CellEditorSheet: View {
    let rowId: UUID
    let holeNumber: Int
    let currentValue: Int?
    let onSave: (Int) -> Void
    let onClear: () -> Void

    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Hole \(holeNumber)")
                    .font(.title2.weight(.bold))

                TextField("Strokes", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 48, weight: .bold))
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 2))

                quickValuesRow

                Spacer()

                HStack(spacing: 12) {
                    Button("Clear", role: .destructive, action: onClear)
                        .buttonStyle(.bordered)
                    Button("Save") {
                        if let n = Int(text), n >= 1, n <= 15 { onSave(n) }
                    }
                    .buttonStyle(BoldPrimaryButtonStyle())
                    .disabled(Int(text).map { $0 < 1 || $0 > 15 } ?? true)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let currentValue { text = String(currentValue) }
            }
        }
    }

    private var quickValuesRow: some View {
        HStack(spacing: 8) {
            ForEach([3, 4, 5, 6, 7, 8], id: \.self) { v in
                Button {
                    text = String(v)
                } label: {
                    Text("\(v)")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Theme.primaryMuted)
                        .clipShape(Circle())
                }
            }
        }
    }
}
