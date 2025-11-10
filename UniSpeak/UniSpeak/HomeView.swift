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
            
            if viewModel.isTranslating {
                ProgressView("Translating...")
                    .padding()
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
        .background(Color.white)
        .padding()
    }
}
