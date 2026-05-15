import SwiftUI
import AVKit
import UIKit

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @State private var manualUrl: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showHistory = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputFocused = false
                    }
                
                // Input UI
                if geo.size.width > geo.size.height {
                    // Landscape Layout
                    HStack(spacing: 40) {
                        // Left: Logo
                        VStack {
                            Spacer()
                            logoView
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right: Input Controls
                        ScrollView {
                            VStack {
                                Spacer(minLength: 20)
                                inputControls
                                historySection
                                Spacer(minLength: 20)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                } else {
                    // Portrait Layout
                    ScrollView {
                        VStack(spacing: 30) {
                            Spacer(minLength: 40)
                            logoView
                            Spacer(minLength: 10)
                            inputControls
                            historySection
                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                }
                
                // Loading overlay
                if vm.isLoading {
                    loadingOverlay
                }
            }
        }
        .alert("Playback Error", isPresented: showErrorBinding) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
    }
    
    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
    
    // MARK: - Components
    
    var logoView: some View {
        VStack {
            Image("AppIconImage")
                 .resizable()
                 .aspectRatio(contentMode: .fit)
                 .frame(width: 120, height: 120)
                 .clipShape(RoundedRectangle(cornerRadius: 24))
                 .shadow(color: .blue.opacity(0.5), radius: 10)
            
            Text("M3U8r")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("Stream Player")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
        }
    }
    
    var inputControls: some View {
        VStack(spacing: 20) {
            // Paste & Play
            Button(action: pasteAndPlay) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste & Play")
                }
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
            }
            .padding(.horizontal, 20)
            
            // Manual Input
            VStack(alignment: .leading, spacing: 12) {
                Text("Or enter URL manually")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.leading)
                
                HStack {
                    TextField("", text: $manualUrl, prompt: Text("https://example.com/stream.m3u8").foregroundColor(.gray.opacity(0.5)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isInputFocused)
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                        .frame(height: 50)
                        .onSubmit {
                            if canSubmitManualURL {
                                vm.play(url: manualUrl)
                            }
                        }
                    
                    if !manualUrl.isEmpty {
                        Button(action: { manualUrl = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.gray)
                                .frame(width: 44, height: 44)
                        }
                        .padding(.trailing, 4)
                    }
                }
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(isInputFocused ? 0.3 : 0.0), lineWidth: 1)
                )
                
                Button(action: { vm.play(url: manualUrl) }) {
                    Text("Play URL")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmitManualURL)
                .opacity(canSubmitManualURL ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
        }
    }
    
    var historySection: some View {
        let history = vm.history
        return Group {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: { withAnimation { showHistory.toggle() } }) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Recent Streams")
                                    .font(.caption.bold())
                                Spacer()
                                Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.gray)
                        }
                        
                        if showHistory {
                            Button(action: {
                                vm.clearHistory()
                            }) {
                                Text("Clear")
                                    .font(.caption2)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                    .padding(.leading)
                    .padding(.trailing)
                    
                    if showHistory {
                        VStack(spacing: 0) {
                            ForEach(history, id: \.self) { url in
                                HStack {
                                    Button(action: {
                                        manualUrl = url
                                        vm.play(url: url)
                                    }) {
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundStyle(.blue)
                                                .font(.body)
                                            
                                            Text(displayName(for: url))
                                                .font(.system(size: 13))
                                                .foregroundStyle(.white.opacity(0.9))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { vm.removeFromHistory(url) }) {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                            .foregroundStyle(.gray.opacity(0.5))
                                            .frame(width: 30, height: 30)
                                    }
                                    .accessibilityLabel("Remove stream from history")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                
                                if url != history.last {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 44)
                                }
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }
    
    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Connecting to stream…")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // MARK: - Logic

    private var canSubmitManualURL: Bool {
        !manualUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func displayName(for url: String) -> String {
        guard let urlObj = URL(string: url) else { return url }
        let name = urlObj.lastPathComponent
            .replacingOccurrences(of: ".m3u8", with: "")
            .replacingOccurrences(of: ".mp4", with: "")
        if name.isEmpty || name == "/" {
            return urlObj.host ?? url
        }
        return name
    }
    
    private func pasteAndPlay() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let string = UIPasteboard.general.string {
            let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                vm.errorMessage = "Clipboard is empty. Copy a stream URL first."
            } else {
                vm.play(url: cleaned)
            }
        } else {
            vm.errorMessage = "Nothing on the clipboard. Copy a stream URL first."
        }
    }
}

#Preview {
    ContentView()
}
