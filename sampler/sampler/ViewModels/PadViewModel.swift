//
//  PadViewModel.swift
//  sampler
//
//  Created by Sijan Khadka on 27/11/2025.
//


import Foundation
import SwiftUI
import AVFoundation
import Combine

final class PadViewModel: ObservableObject {
    @Published var pads: [Pad] = (0..<8).map { Pad(id: $0, sample: nil) }
    @Published var isRecording: Bool = false
    @Published var lastRecordingURL: URL?
    
    private let audioManager = AudioEngineManager.shared
    
    // Start recording to a temp file
    func startRecording() {
        // temp file in Caches
        let filename = "sample_\(UUID().uuidString).caf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try audioManager.startRecording(to: url)
            isRecording = true
        } catch {
            print("startRecording failed:", error)
            isRecording = false
        }
    }
    
    func stopRecording() {
        audioManager.stopRecording()
        isRecording = false
        
        // Recording file should exist at lastRecordingURL (AudioEngineManager recorded to the url we passed)
        // We need a way to get that path: we created it locally so we saved it
        // For simplicity, we discover the most recent file in tmp (best-effort)
        let tmp = FileManager.default.temporaryDirectory
        if let url = try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
            .sorted(by: {
                (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast >
                (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            }).first {
            lastRecordingURL = url
        }
    }
    
    func assignLastRecording(to padIndex: Int) {
        guard let url = lastRecordingURL else { return }
        // get duration
        do {
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.fileFormat.sampleRate
            let sample = PadSample(fileURL: url, duration: duration)
            pads[padIndex].sample = sample
            // clear lastRecordingURL so user must record again if reassign
            lastRecordingURL = nil
        } catch {
            print("Failed reading file for duration:", error)
        }
    }
    
    func playPad(_ index: Int) {
        guard index >= 0 && index < pads.count, let sample = pads[index].sample else { return }
        audioManager.playSample(from: sample.fileURL)
    }
    
    func stopAll() {
        audioManager.stopAll()
    }
    
    // For quick cleanup
    func clearPad(_ index: Int) {
        pads[index].sample = nil
    }
}
