//
//  SpeechStreamRecognizer.swift
//  Runner
//
//  Created by edy on 2024/4/16.
//
import AVFoundation
import Speech

class SpeechStreamRecognizer {
    static let shared = SpeechStreamRecognizer()
    
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastRecognizedText: String = "" // latest accepeted recognized text
    // private var previousRecognizedText: String = ""
    let languageDic = [
        "CN": "zh-CN",
        "EN": "en-US",
        "RU": "ru-RU",
        "KR": "ko-KR",
        "JP": "ja-JP",
        "ES": "es-ES",
        "FR": "fr-FR",
        "DE": "de-DE",
        "NL": "nl-NL",
        "NB": "nb-NO",
        "DA": "da-DK",
        "SV": "sv-SE",
        "FI": "fi-FI",
        "IT": "it-IT"
    ]
    
    let dateFormatter = DateFormatter()
    
    private var lastTranscription: SFTranscription? // cache to make contrast between near results
    private var cacheString = "" // cache stream recognized formattedString
    
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    private init() {
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        if #available(iOS 13.0, *) {
            Task {
                do {
                    guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                        throw RecognizerError.notAuthorizedToRecognize
                    }
                    /*
                     guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                     throw RecognizerError.notPermittedToRecord
                     }*/
                } catch {
                    print("SFSpeechRecognizer------permission error----\(error)")
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func startRecognition(identifier: String) {
        lastTranscription = nil
        self.lastRecognizedText = ""
        cacheString = ""
        
        let localIdentifier = languageDic[identifier]
        print("startRecognition----localIdentifier----\(localIdentifier)--identifier---\(identifier)---")
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localIdentifier ?? "en-US"))  // en-US zh-CN en-US
        guard let recognizer = recognizer else {
            print("Speech recognizer is not available")
            return
        }
        
        guard recognizer.isAvailable else {
            print("startRecognition recognizer is not available")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            //try audioSession.setCategory(.record)
            try audioSession.setCategory(.playback, options: .mixWithOthers)
            try audioSession.setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true //true
        recognitionRequest.requiresOnDeviceRecognition = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print("SpeechRecognizer Recognition error: \(error)")
            } else if let result = result {
                    
                let currentTranscription = result.bestTranscription
                if lastTranscription == nil {
                    cacheString = currentTranscription.formattedString
                } else {
                    
                    if (currentTranscription.segments.count < lastTranscription?.segments.count ?? 1 || currentTranscription.segments.count == 1) {
                        self.lastRecognizedText += cacheString
                        cacheString = ""
                    } else {
                        cacheString = currentTranscription.formattedString
                    }
                }
                
                lastTranscription = result.bestTranscription
            }
        }
    }
    
    func stopRecognition() {

        print("stopRecognition-----self.lastRecognizedText-------\(self.lastRecognizedText)------cacheString----------\(cacheString)---")
        self.lastRecognizedText += cacheString

        DispatchQueue.main.async {
            BluetoothManager.shared.blueSpeechSink?(["script": self.lastRecognizedText])
        }
        
        recognitionTask?.cancel()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error stop audio session: \(error)")
            return
        }
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
    }
    
    func appendPCMData(_ pcmData: Data) {
        print("appendPCMData-------pcmData------\(pcmData.count)--")
        guard let recognitionRequest = recognitionRequest else {
            print("Recognition request is not available")
            return
        }

        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(pcmData.count) / audioFormat.streamDescription.pointee.mBytesPerFrame) else {
            print("Failed to create audio buffer")
            return
        }
        audioBuffer.frameLength = audioBuffer.frameCapacity

        pcmData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            if let audioDataPointer = bufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                let audioBufferPointer = audioBuffer.int16ChannelData?.pointee
                audioBufferPointer?.initialize(from: audioDataPointer, count: pcmData.count / MemoryLayout<Int16>.size)
                recognitionRequest.append(audioBuffer)
            } else {
                print("Failed to get pointer to audio data")
            }
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}


