//
//  AudioEngineManager.swift
//  sampler
//
//  Created by Sijan Khadka on 27/11/2025.
//


import Foundation
import AVFoundation

final class AudioEngineManager {
    static let shared = AudioEngineManager()
    
    private let engine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode
    private var playerNodes: [AVAudioPlayerNode] = []
    private var filePlayers: [AVAudioFile] = []
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?
    private var isRecording = false
    private let audioFormat: AVAudioFormat
    
    private init() {
        mainMixer = engine.mainMixerNode
        // Use hardware sample rate and channel count
        let hwFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        audioFormat = hwFormat
        setupEngine()
    }
    
    private func setupEngine() {
        let input = engine.inputNode
        let output = engine.outputNode // Get the output node for clarity
        
        // 1. Connect Input -> Main Mixer (Use nil format to allow engine to figure it out)
        engine.connect(input, to: mainMixer, format: nil)
        
        // 2. Connect Main Mixer -> Output Node (Use nil format)
        engine.connect(mainMixer, to: output, format: nil)
        
        engine.prepare()
        // 🛑 Keep engine.start() REMOVED
    }
    
    // MARK: - Recording via inputNode tap to file
    func startRecording(to url: URL) throws {
        guard !isRecording else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [
                .mixWithOthers,
                .allowBluetoothHFP, // <-- CORRECTED: Removed 'AVAudioSession.CategoryOptions.'
                .allowBluetoothA2DP,
                .defaultToSpeaker
            ])
        try session.setActive(true, options: [])
        
        if !engine.isRunning {
                try engine.start() // 🚨 Engine starts AFTER session is active
            }
        
        engine.inputNode.volume = 0.0
        
        
        let hwFormat = AVAudioFormat(
            standardFormatWithSampleRate: session.sampleRate,
            channels: AVAudioChannelCount(session.inputNumberOfChannels)
        )

        guard let recordingFormat = hwFormat else {
            throw NSError(domain: "SamplerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create recording format from active session."])
        }
        
        recordingURL = url
        
        do {
                // Use the hardware-backed format
                recordingFile = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
            } catch {
                print("Failed to create recording file", error)
                throw error
            }
        
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in            guard let self = self, let file = self.recordingFile else { return }
            do {
                try file.write(from: buffer)
            } catch {
                print("Error writing buffer to file:", error)
            }
        }
        
        
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        recordingFile = nil
        isRecording = false
        // Keep session active so we can play immediately, but you can deactivate if desired
    }
    
    // MARK: - Playback
    /// Play an audio file at url. Supports overlapping playbacks by creating a new player node each time.
    func playSample(from url: URL) {
        // 1. Read the file data on a background thread (this is the potentially slow operation)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try AVAudioFile(forReading: url)
                
                // 2. Switch to the main thread for engine modifications (topology changes)
                DispatchQueue.main.async {
                    let player = AVAudioPlayerNode()
                    self.playerNodes.append(player)
                    
                    // --- Engine Topology Changes START ---
                    self.engine.attach(player)
                    self.engine.connect(player, to: self.mainMixer, format: file.processingFormat)
                    
                    player.scheduleFile(file, at: nil) {
                        // cleanup after play finished - remove node
                        // This completion block is already on a high-priority thread, so ensure cleanup is safe
                        DispatchQueue.main.async {
                            player.stop()
                            self.engine.detach(player)
                            self.playerNodes.removeAll { $0 === player }
                        }
                    }
                    
                    // Start engine if needed (also a topology change/state change)
                    if !self.engine.isRunning {
                        try? self.engine.start() // Use try? since we are not in a throwing context
                    }
                    
                    player.play()
                    // --- Engine Topology Changes END ---
                }
            } catch {
                print("Playback error:", error)
            }
        }
    }
    
    // Utility to stop all sounds
    func stopAll() {
        for node in playerNodes {
            node.stop()
            engine.detach(node)
        }
        playerNodes.removeAll()
    }
    
    func toggleInputMonitoring(enable: Bool) {
        // Set the volume of the input node to 0.0 (mute) or 1.0 (enable)
        engine.inputNode.volume = enable ? 1.0 : 0.0
    }
}
