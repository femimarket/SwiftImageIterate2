//
//  ContentView.swift
//  Playground
//
//  Chip-list prompt builder prototype.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var chips: [Chip] = [
        Chip(text: "cinematic golden hour"),
        Chip(text: "lone figure on a street"),
        Chip(text: "soft film grain"),
    ]
    @State private var editingId: Chip.ID?
    @State private var editingText: String = ""
    @State private var newChipText: String = ""
    @State private var addingNew = false

    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case edit(UUID)
        case add
    }

    private let presets = ["Cinematic", "Neon", "Moody", "Pastel", "Film", "Surreal", "Vintage", "Dreamy"]
    /// Soft cap: prompts beyond this length stop adding new chips. Prevents
    /// runaway lists from making the flow layout enormous and the joined
    /// prompt potentially over backend limits. Existing chips can still be
    /// edited and removed.
    private let maxChips = 20
    private var atCap: Bool { chips.count >= maxChips }

    // MARK: Haptics

    private static let lightHaptic = UIImpactFeedbackGenerator(style: .soft)
    private static let mediumHaptic = UIImpactFeedbackGenerator(style: .light)
    private func tap(_ feedback: UIImpactFeedbackGenerator = ContentView.lightHaptic) {
        feedback.impactOccurred()
    }

    var body: some View {
        ZStack {
            // Ambient background.
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.42, green: 0.10, blue: 0.55).opacity(0.35), .clear],
                center: .init(x: 0.18, y: 0.05), startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.95, green: 0.30, blue: 0.55).opacity(0.22), .clear],
                center: .init(x: 0.92, y: 0.08), startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionLabel("PROMPT")
                        chipFlow
                            .padding(.horizontal, 16)

                        sectionLabel("PRESETS")
                        presetRail

                        sectionLabel("PREVIEW")
                        previewBlock
                    }
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                generateButton
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
            }
        }
        .preferredColorScheme(.dark)
        // Keyboard Done button — canonical iOS dismiss-while-editing. Replaces
        // the previous tap-outside layer (which the ScrollView was swallowing).
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissAll() }
                    .foregroundStyle(Color(red: 1.0, green: 0.30, blue: 0.65))
                    .font(.system(size: 15, weight: .semibold))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.20, blue: 1.0),
                                 Color(red: 1.0, green: 0.30, blue: 0.65)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: 8, height: 8)
                Text("PROMPT CHIPS")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(2.8)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 22)
    }

    // MARK: Chip flow

    private var chipFlow: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChipFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(chips) { chip in
                    chipView(chip)
                }
                addChipView
            }
            if chips.isEmpty && !addingNew {
                Text("tap + to begin engineering your prompt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func chipView(_ chip: Chip) -> some View {
        if editingId == chip.id {
            inlineEditor(for: chip)
        } else {
            HStack(spacing: 6) {
                Text(chip.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 220, alignment: .leading)
                    .onTapGesture {
                        beginEdit(chip)
                    }
                    .accessibilityHint("Double-tap to edit")
                Button {
                    remove(chip)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(chip.text)")
            }
            .padding(.leading, 14)
            .padding(.trailing, 5)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private func inlineEditor(for chip: Chip) -> some View {
        AutoChipField(
            text: $editingText,
            placeholder: "",
            maxWidth: 240,
            submitLabel: .done,
            onSubmit: { commitEdit() },
            focus: $focusedField,
            focusValue: .edit(chip.id)
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.14)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.7))
    }

    @ViewBuilder
    private var addChipView: some View {
        if atCap && !addingNew {
            // At soft cap — hide the add affordance entirely so the user can
            // see the wall. Editing and removal still work to free up slots.
            EmptyView()
        } else {
            addChipBody
        }
    }

    private var addChipBody: some View {
        Group {
            if addingNew {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    AutoChipField(
                        text: $newChipText,
                        placeholder: "phrase",
                        maxWidth: 240,
                        submitLabel: .next,
                        onSubmit: { commitAndContinueAdd() },
                        focus: $focusedField,
                        focusValue: .add
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.14)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.7))
            } else {
                Button {
                    beginAdd()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.04)))
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(0.18),
                                               style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add phrase")
            }
        }
    }

    // MARK: Preset rail

    private var presetRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { p in
                    Button {
                        insertPreset(p)
                    } label: {
                        Text(p)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.06)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: Preview

    private var previewBlock: some View {
        Text(joinedPrompt.isEmpty ? "—" : joinedPrompt)
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundStyle(.white.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 22)
    }

    private var joinedPrompt: String {
        chips.map(\.text).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // MARK: Generate

    private var generateButton: some View {
        Button {
            print("⟶ generate: \(joinedPrompt)")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                Text("Generate")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.20, blue: 1.0),
                                 Color(red: 1.0, green: 0.30, blue: 0.65)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .top, endPoint: .center
                    ).blendMode(.plusLighter).opacity(0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.7)
            }
            .shadow(color: Color(red: 0.95, green: 0.30, blue: 0.65).opacity(0.45), radius: 24, y: 10)
            .opacity(chips.isEmpty ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(chips.isEmpty)
    }

    // MARK: Actions

    private func beginEdit(_ chip: Chip) {
        // Commit any in-flight edit BEFORE switching to a new chip, otherwise
        // the previous chip's typed-but-uncommitted text gets silently dropped.
        commitEdit()
        commitAdd()
        tap()
        editingId = chip.id
        editingText = chip.text
        DispatchQueue.main.async {
            focusedField = .edit(chip.id)
        }
    }

    private func commitEdit() {
        guard let id = editingId else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespaces)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if trimmed.isEmpty {
                chips.removeAll { $0.id == id }
            } else if let idx = chips.firstIndex(where: { $0.id == id }) {
                chips[idx].text = trimmed
            }
            editingId = nil
            editingText = ""
        }
    }

    private func remove(_ chip: Chip) {
        tap(ContentView.mediumHaptic)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            chips.removeAll { $0.id == chip.id }
        }
    }

    private func beginAdd() {
        commitEdit()
        tap()
        addingNew = true
        newChipText = ""
        DispatchQueue.main.async {
            focusedField = .add
        }
    }

    private func commitAndContinueAdd() {
        guard addingNew else { return }
        let trimmed = newChipText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            addingNew = false
            newChipText = ""
            focusedField = nil
            return
        }
        if atCap {
            // Soft cap reached. Bounce the field as a signal, keep what was
            // typed so the user can edit it down rather than losing it.
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            chips.append(Chip(text: trimmed))
            newChipText = ""
        }
        DispatchQueue.main.async {
            focusedField = .add
        }
    }

    private func commitAdd() {
        guard addingNew else { return }
        let trimmed = newChipText.trimmingCharacters(in: .whitespaces)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if !trimmed.isEmpty && !atCap {
                chips.append(Chip(text: trimmed))
            }
            addingNew = false
            newChipText = ""
        }
    }

    private func insertPreset(_ name: String) {
        commitEdit()
        commitAdd()
        guard !atCap else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            chips.append(Chip(text: name.lowercased()))
        }
    }

    private func dismissAll() {
        commitEdit()
        commitAdd()
        focusedField = nil
    }
}

// MARK: - Model

struct Chip: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

// MARK: - AutoChipField
//
// TextField that sizes to its content width (plus a small padding) up to
// `maxWidth`. Uses a hidden Text mirror as the measurement source via
// PreferenceKey — width follows the typed content reactively without a
// one-frame lag.

private struct AutoChipField: View {
    @Binding var text: String
    var placeholder: String
    var maxWidth: CGFloat
    var font: Font = .system(size: 14, weight: .medium)
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void
    @FocusState.Binding var focus: ContentView.Field?
    var focusValue: ContentView.Field

    @State private var measuredWidth: CGFloat = 70

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundColor(.white.opacity(0.35))
        )
        .focused($focus, equals: focusValue)
        .font(font)
        .foregroundStyle(.white)
        .tint(.white)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .frame(width: measuredWidth)
        .background(measuringMirror)
        .onPreferenceChange(ChipWidthKey.self) { w in
            measuredWidth = min(max(60, w + 4), maxWidth)
        }
    }

    private var measuringMirror: some View {
        Text(text.isEmpty ? placeholder : text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ChipWidthKey.self, value: geo.size.width)
                }
            )
            .opacity(0)
    }
}

private struct ChipWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 70
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - FlowLayout

/// Wraps child views onto multiple lines, like text. Each line left-aligned.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                maxLineWidth = max(maxLineWidth, x - spacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        maxLineWidth = max(maxLineWidth, x - spacing)
        return CGSize(width: maxLineWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    ContentView()
}
