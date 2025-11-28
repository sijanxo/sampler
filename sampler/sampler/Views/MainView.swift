//
//  MainView.swift
//  sampler
//
//  Created by Sijan Khadka on 27/11/2025.
//


import SwiftUI
import AVFoundation

struct MainView: View {
    @EnvironmentObject var vm: PadViewModel
    @State private var showAssignHint = false
    @State private var assigningMode = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: status
            HStack {
                Text(vm.isRecording ? "Recording…" : (vm.lastRecordingURL != nil ? "Recorded — assign to a pad" : "Ready"))
                    .font(.headline)
                Spacer()
                Button(action: {
                    vm.stopAll()
                }) {
                    Text("Stop All")
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)
            
            // Pad grid 4x2 (4 columns, 2 rows)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.pads) { pad in
                    PadView(pad: pad, assigningMode: $assigningMode)
                        .frame(height: 120)
                        .onTapGesture {
                            if assigningMode {
                                if vm.lastRecordingURL == nil {
                                    alertMessage = "No recent recording to assign. Record first."
                                    showAlert = true
                                    return
                                }
                                vm.assignLastRecording(to: pad.id)
                                assigningMode = false
                            } else {
                                if pad.sample == nil {
                                    alertMessage = "Pad empty. Long-press to assign or record then assign."
                                    showAlert = true
                                } else {
                                    vm.playPad(pad.id)
                                }
                            }
                        }
                        .onLongPressGesture {
                            // long-press to clear pad
                            vm.clearPad(pad.id)
                        }
                }
            }
            .padding(.horizontal)
            
            // Controls: Record / Assign Mode / Clear Recent
            HStack(spacing: 12) {
                Button(action: {
                    if vm.isRecording {
                        vm.stopRecording()
                        // after stop, enter assigning mode automatically
                        if vm.lastRecordingURL != nil {
                            assigningMode = true
                        }
                    } else {
                        // request permission before recording
                        AVAudioApplication.requestRecordPermission { granted in // <-- Add 'granted in' here
                            DispatchQueue.main.async {
                                if granted { // <-- Now 'granted' is in scope
                                    vm.startRecording()
                                } else {
                                    alertMessage = "Microphone permission denied. Enable in Settings."
                                    showAlert = true
                                }
                            }
                        }
                    }})
            {
                    Text(vm.isRecording ? "Stop" : "Record")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.isRecording ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    // If there's a recent recording, toggle assigning mode
                    if vm.lastRecordingURL == nil {
                        alertMessage = "No recent recording to assign. Record first."
                        showAlert = true
                        return
                    }
                    assigningMode.toggle()
                }) {
                    Text(assigningMode ? "Assigning: Tap a pad" : "Assign")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(assigningMode ? Color.green : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    // clear last recording (temp file)
                    if let url = vm.lastRecordingURL {
                        try? FileManager.default.removeItem(at: url)
                        vm.lastRecordingURL = nil
                    }
                }) {
                    Text("Clear")
                        .frame(width: 80)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Note"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            
            Spacer()
            Text("Long-press a pad to clear it. After recording, use Assign to map the sample.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

struct PadView: View {
    let pad: Pad
    @Binding var assigningMode: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .shadow(radius: 2)
            VStack {
                Text("Pad \(pad.id + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                if let sample = pad.sample {
                    Text(String(format: "%.2fs", sample.duration))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                } else {
                    Text("Empty")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(8)
        }
    }
    
    var color: Color {
        if assigningMode {
            return Color.yellow
        } else if pad.sample != nil {
            return Color.blue
        } else {
            return Color.gray
        }
    }
}
