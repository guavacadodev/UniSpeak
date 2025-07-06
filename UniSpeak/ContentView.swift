//  VoiceTranslator.swift
//  UniSpeak

import SwiftUI
import Speech
import AVFoundation

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Group {
                Text("You said:")
                    .font(.headline)
                Text(viewModel.spokenText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.spokenText)

                Text("Translated:")
                    .font(.headline)
                Text(viewModel.translatedText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .transition(.scale)
                    .animation(.spring(), value: viewModel.translatedText)
            }

            Picker("Language", selection: $viewModel.selectedLanguage) {
                ForEach(["French", "Spanish", "German", "Japanese", "Chinese"], id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Button(action: {
                viewModel.isListening ? viewModel.stopListening() : viewModel.startListening()
            }) {
                HStack {
                    Image(systemName: viewModel.isListening ? "stop.circle" : "mic.circle")
                    Text(viewModel.isListening ? "Stop Listening" : "Start Listening")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(viewModel.isListening ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 5)
            }
            .padding(.top)
        }
        .padding()
    }
}

import SwiftUI
import Speech
import AVFoundation

class HomeViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var spokenText = ""
    @Published var translatedText = ""
    @Published var isListening = false
    @Published var selectedLanguage = "French"

    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var silenceTimer: Timer?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func startListening() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error)")
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            print("Invalid format")
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.spokenText = text
                }

                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    self.stopListening()
                    self.handleFinalTranscript(text)
                }

            } else if let error = error {
                print("Recognition error: \(error)")
                self.stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        silenceTimer?.invalidate()
    }

    private func handleFinalTranscript(_ text: String) {
        let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { return }

        translateWithOpenAI(text: finalText, to: selectedLanguage) { translated in
            DispatchQueue.main.async {
                self.translatedText = translated
                self.speak(translated)
            }
        }
    }

    func speak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: nil)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    func translateWithOpenAI(text: String, to targetLanguage: String, completion: @escaping (String) -> Void) {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("Missing API key")
            return
        }

        let prompt = "Translate this to \(targetLanguage):\n\n\(text)"
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": prompt]]
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions"),
              let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let translated = message["content"] as? String else {
                print("Translation failed")
                return
            }
            completion(translated.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !audioEngine.isRunning {
            startListening()
        }
    }
}
