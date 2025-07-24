//
//  AudioRecorderService.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Servicio para grabar mensajes de voz

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    static let shared = AudioRecorderService()
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Setup Audio Session
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            // Request permission
            session.requestRecordPermission { [weak self] granted in
                if !granted {
                    Task { @MainActor in
                        self?.errorMessage = "Permiso de micrófono denegado"
                    }
                }
            }
        } catch {
            errorMessage = "Error configurando audio: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Start Recording
    
    func startRecording() async throws -> Bool {
        // Check permission
        let session = AVAudioSession.sharedInstance()
        
        // Request permission with async/await
        let granted = await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard granted else {
            errorMessage = "Permiso de micrófono denegado"
            return false
        }
        
        // Generate unique filename
        let fileName = "voice_message_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.temporaryDirectory
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let recordingURL = recordingURL else { return false }
        
        // Configure recorder settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Start recording
            audioRecorder?.record()
            isRecording = true
            recordingTime = 0
            
            // Start timers
            startTimers()
            
            return true
        } catch {
            errorMessage = "Error iniciando grabación: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Stop Recording
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        isRecording = false
        
        // Stop timers
        stopTimers()
        
        // Reset audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        return recordingURL
    }
    
    // MARK: - Cancel Recording
    
    func cancelRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        isRecording = false
        
        // Stop timers
        stopTimers()
        
        // Reset
        recordingTime = 0
        audioLevel = 0
        recordingURL = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    // MARK: - Timers
    
    private func startTimers() {
        // Recording time timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
                
                // Limit recording to 5 minutes
                if self?.recordingTime ?? 0 >= 300 {
                    _ = self?.stopRecording()
                }
            }
        }
        
        // Audio level timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        
        // Get average power in decibels
        let avgPower = recorder.averagePower(forChannel: 0)
        
        // Convert to 0-1 scale
        // -160 dB (silent) to 0 dB (loud)
        let minDb: Float = -60
        let normalized = max(0, (avgPower - minDb) / -minDb)
        
        Task { @MainActor in
            self.audioLevel = normalized
        }
    }
    
    // MARK: - Format Duration
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Get Audio Duration
    
    func getAudioDuration(from url: URL) -> TimeInterval? {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        return CMTimeGetSeconds(duration)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                errorMessage = "Error al finalizar la grabación"
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = "Error de codificación: \(error?.localizedDescription ?? "desconocido")"
        }
    }
}