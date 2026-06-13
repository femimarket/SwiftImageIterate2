//
//  ContentView.swift
//  ImageIterate2
//
//  One image, many iterations.
//

import SwiftUI
import UIKit

// MARK: - Theme

private enum Theme {
    static let bg              = Color.black
    static let surface         = Color.white.opacity(0.06)
    static let surfaceStrong   = Color.white.opacity(0.10)
    static let stroke          = Color.white.opacity(0.10)
    static let textDim         = Color.white.opacity(0.5)

    static let accent = LinearGradient(
        colors: [
            Color(red: 0.55, green: 0.20, blue: 1.00),
            Color(red: 1.00, green: 0.30, blue: 0.65)
        ],
        startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - Models

struct Variation: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: Variation, rhs: Variation) -> Bool { lhs.id == rhs.id }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var hero: UIImage = ContentView.makeDemoImage()
    @State private var history: [UIImage] = []
    @State private var variations: [Variation] = []
    @State private var selectedVibes: Set<String> = []
    @State private var prompt: String = ""
    @State private var isGenerating = false
    @State private var pendingPlaceholders = 0
    @State private var heroBreath = false
    @State private var errorBanner: String?

    @FocusState private var promptFocused: Bool

    private let vibes = ["Cinematic", "Neon", "Moody", "Pastel", "Film", "Surreal", "Vintage", "Dreamy"]

    var body: some View {
        ZStack {
            ambientBackground

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 22) {
                        heroCard
                            .padding(.horizontal, 22)
                            .padding(.top, 4)

                        if !history.isEmpty {
                            historyStrip
                        }

                        if !variations.isEmpty || pendingPlaceholders > 0 {
                            variationsRail
                        }
                    }
                    .padding(.bottom, 230)
                }
                .scrollIndicators(.hidden)
            }

            VStack {
                Spacer()
                if let msg = errorBanner {
                    errorPill(msg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .background(Theme.bg)
        .onAppear { heroBreath = true }
        .onTapGesture { promptFocused = false }
    }

    // MARK: Background

    private var ambientBackground: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.42, green: 0.10, blue: 0.55).opacity(0.40), .clear],
                center: .init(x: 0.18, y: 0.02),
                startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.95, green: 0.30, blue: 0.55).opacity(0.25), .clear],
                center: .init(x: 0.92, y: 0.06),
                startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(Theme.accent).frame(width: 8, height: 8)
                Text("ITERATE")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(2.8)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            iconButton(symbol: "xmark") { }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    private func iconButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Hero

    private var heroCard: some View {
        Image(uiImage: hero)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.20), .clear, .black.opacity(0.18)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.55)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.40), .white.opacity(0.04), .white.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .overlay {
                if isGenerating { ShimmerView().clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous)).allowsHitTesting(false) }
            }
            .shadow(color: Color(red: 0.95, green: 0.30, blue: 0.65).opacity(0.28), radius: 44, y: 22)
            .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
            .scaleEffect(heroBreath ? 1.006 : 1.0)
            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: heroBreath)
    }

    // MARK: History strip

    private var historyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("HISTORY")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Theme.textDim)
                    .padding(.leading, 22)
                    .padding(.trailing, 4)
                ForEach(Array(history.enumerated()), id: \.offset) { idx, img in
                    Button {
                        revert(to: idx)
                    } label: {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                }
                Color.clear.frame(width: 22)
            }
        }
    }

    // MARK: Variations

    private var variationsRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Color.clear.frame(width: 8)
                ForEach(0..<pendingPlaceholders, id: \.self) { _ in
                    placeholderCard
                        .transition(.opacity)
                }
                ForEach(variations) { v in
                    variationCard(v)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                Color.clear.frame(width: 8)
            }
            .padding(.horizontal, 14)
        }
    }

    private func variationCard(_ v: Variation) -> some View {
        Button { promote(v) } label: {
            Image(uiImage: v.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 168, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.16), .clear, .black.opacity(0.12)],
                            startPoint: .top, endPoint: .bottom))
                        .blendMode(.plusLighter)
                        .opacity(0.7)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.20), lineWidth: 0.6)
                }
                .shadow(color: .black.opacity(0.50), radius: 16, y: 8)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }

    private var placeholderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
            ShimmerView()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(width: 168, height: 168)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vibes, id: \.self) { v in
                        VibePill(label: v, isSelected: selectedVibes.contains(v)) {
                            toggleVibe(v)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }

            HStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                TextField("", text: $prompt, prompt:
                    Text("optional · refine the vibe")
                        .foregroundColor(Theme.textDim)
                )
                .focused($promptFocused)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .tint(.white)
                .submitLabel(.go)
                .onSubmit { Task { await generate() } }
                if !prompt.isEmpty {
                    Button { prompt = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.35))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5))
            .padding(.horizontal, 22)

            generateButton
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
        }
        .padding(.top, 18)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.75), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var generateButton: some View {
        Button { Task { await generate() } } label: {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView().tint(.white).scaleEffect(0.9)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .bold))
                }
                Text(isGenerating ? "Generating" : "Generate")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                ZStack {
                    Theme.accent
                    LinearGradient(
                        colors: [.white.opacity(0.38), .clear],
                        startPoint: .top, endPoint: .center
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.55)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.28)],
                        startPoint: .center, endPoint: .bottom
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            }
            .shadow(color: Color(red: 0.95, green: 0.30, blue: 0.65).opacity(0.55), radius: 26, y: 12)
            .shadow(color: Color(red: 0.55, green: 0.20, blue: 1.0).opacity(0.35), radius: 14, y: 4)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .disabled(isGenerating)
    }

    private func errorPill(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(.red.opacity(0.85)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            .padding(.bottom, 8)
    }

    // MARK: Actions

    private func toggleVibe(_ vibe: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            if selectedVibes.contains(vibe) { selectedVibes.remove(vibe) }
            else { selectedVibes.insert(vibe) }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func promote(_ v: Variation) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            history.append(hero)
            hero = v.image
            variations.removeAll { $0.id == v.id }
        }
    }

    private func revert(to idx: Int) {
        guard idx < history.count else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let restored = history[idx]
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            history.append(hero)
            hero = restored
            history.remove(at: idx)
        }
    }

    private func generate() async {
        promptFocused = false
        guard !isGenerating else { return }

        let vibeText = selectedVibes.sorted().joined(separator: ", ")
        let parts = [prompt.trimmingCharacters(in: .whitespaces), vibeText].filter { !$0.isEmpty }
        let finalPrompt = parts.isEmpty ? "creative reinterpretation, preserve subject" : parts.joined(separator: ", ")

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isGenerating = true
            pendingPlaceholders = 2
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        let baseImage = hero

        do {
            let images = try await ImageService.shared.generate(
                prompt: finalPrompt,
                baseImage: baseImage,
                count: 2
            )
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                for img in images {
                    variations.insert(Variation(image: img), at: 0)
                }
                pendingPlaceholders = 0
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            withAnimation(.spring()) {
                pendingPlaceholders = 0
                errorBanner = error.localizedDescription
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.spring()) { errorBanner = nil }
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isGenerating = false
        }
    }

    // MARK: Demo image

    static func makeDemoImage() -> UIImage {
        let renderer = ImageRenderer(content: DemoImageCanvas())
        renderer.scale = 2.0
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - VibePill

private struct VibePill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(isSelected ? .black : .white.opacity(0.88))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule().fill(.white)
                            .shadow(color: .white.opacity(0.35), radius: 10, y: 0)
                    } else {
                        Capsule().fill(Theme.surface)
                    }
                }
                .overlay {
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Theme.stroke,
                        lineWidth: 0.5
                    )
                }
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }
}

// MARK: - Shimmer

private struct ShimmerView: View {
    @State private var phase: CGFloat = -1.0
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.white.opacity(0.0), .white.opacity(0.22), .white.opacity(0.0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.55)
            .offset(x: geo.size.width * phase)
            .blendMode(.plusLighter)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
        }
    }
}

// MARK: - Button style

private struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Demo image canvas (hardcoded "input" image)

private struct DemoImageCanvas: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.02, blue: 0.22),
                    Color(red: 0.32, green: 0.06, blue: 0.48),
                    Color(red: 0.70, green: 0.14, blue: 0.40),
                    Color(red: 0.98, green: 0.32, blue: 0.32)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.55), .clear],
                    center: .center, startRadius: 0, endRadius: 330))
                .frame(width: 720, height: 720)
                .offset(x: -180, y: -290)
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.45, blue: 0.85).opacity(0.7), .clear],
                    center: .center, startRadius: 0, endRadius: 240))
                .frame(width: 500, height: 500)
                .offset(x: 210, y: 250)
            Rectangle()
                .fill(.white.opacity(0.05))
                .frame(height: 1)
                .offset(y: 70)
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Image Service (z-image-turbo)

enum ImageServiceError: LocalizedError {
    case encodingFailed
    case requestFailed(String)
    case decodingFailed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .encodingFailed:        return "couldn't encode image"
        case .requestFailed(let s):  return s
        case .decodingFailed:        return "couldn't read result"
        case .timedOut:              return "took too long"
        }
    }
}

private enum APIResult {
    case url(URL)
    case data(Data)
}

final class ImageService {
    static let shared = ImageService()

    private let bearer  = "019ec07a-c943-7275-b758-2315b8c9fa6f"
    private let baseURL = URL(string: "https://api.z.ai/api/paas/v4/images/generations")!
    private let model   = "z-image-turbo"

    func generate(prompt: String, baseImage: UIImage, count: Int) async throws -> [UIImage] {
        try await withThrowingTaskGroup(of: UIImage?.self) { group in
            for _ in 0..<count {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return try? await self.singleGenerate(prompt: prompt, baseImage: baseImage)
                }
            }
            var images: [UIImage] = []
            for try await img in group { if let img { images.append(img) } }
            if images.isEmpty { throw ImageServiceError.requestFailed("no images returned") }
            return images
        }
    }

    private func singleGenerate(prompt: String, baseImage: UIImage) async throws -> UIImage {
        guard let jpeg = baseImage.jpegData(compressionQuality: 0.85) else {
            throw ImageServiceError.encodingFailed
        }
        let dataURI = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"

        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "prompt": prompt,
            "image": dataURI,
            "size": "1024x1024",
            "n": 1
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ImageServiceError.requestFailed("no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ImageServiceError.requestFailed(body.prefix(140).description)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let result = extractImage(from: json) {
            return try await materialize(result)
        }
        if let taskId = (json?["task_id"] as? String) ?? (json?["id"] as? String) {
            return try await pollUntilDone(taskId: taskId)
        }
        throw ImageServiceError.decodingFailed
    }

    private func extractImage(from json: [String: Any]?) -> APIResult? {
        guard let json else { return nil }
        let candidates: [[String: Any]]
        if let arr = json["data"] as? [[String: Any]] {
            candidates = arr
        } else {
            candidates = [json]
        }
        for item in candidates {
            if let s = (item["url"] as? String) ?? (item["image_url"] as? String),
               let url = URL(string: s) { return .url(url) }
            if let b64 = item["b64_json"] as? String,
               let raw = Data(base64Encoded: b64) { return .data(raw) }
        }
        return nil
    }

    private func materialize(_ result: APIResult) async throws -> UIImage {
        switch result {
        case .url(let url):
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else { throw ImageServiceError.decodingFailed }
            return img
        case .data(let data):
            guard let img = UIImage(data: data) else { throw ImageServiceError.decodingFailed }
            return img
        }
    }

    private func pollUntilDone(taskId: String) async throws -> UIImage {
        let pollURL = URL(string: "https://api.z.ai/api/paas/v4/async-result/\(taskId)")!
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            var req = URLRequest(url: pollURL)
            req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = (parsed?["task_status"] as? String) ?? (parsed?["status"] as? String) ?? ""
            if ["SUCCESS", "completed", "succeeded"].contains(status) {
                if let result = extractImage(from: parsed) {
                    return try await materialize(result)
                }
            }
            if ["FAILED", "failed", "error"].contains(status) {
                throw ImageServiceError.requestFailed("task failed")
            }
        }
        throw ImageServiceError.timedOut
    }
}

#Preview {
    ContentView()
}
