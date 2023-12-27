//
//  ContentViewModel.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import Foundation

class ContentViewModel: ObservableObject {
    let audioPlayer = AudioPlayer()
    
    let audioExtractor = AudioExtractor()
    
    let audioConverter = NoiseSuppressor()
    
    lazy var fileUrl = getDocumentDirectory().appendingPathComponent("AudioSample.wav")
    
    private func getDocumentDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func playOriginalAudioFile() {
        if let audioData = audioExtractor.extractDataFromAudioFile(at: fileUrl) {
            audioPlayer.playAudioData(data: audioData)
        } else {
            audioPlayer.playAudioFile(from: fileUrl)
        }
    }
    
    func playAppliedDTLNAudioFile() {
        let convert: (Data) -> Void = { data in
            self.audioConverter.convert(data: data) { resultData in
                self.audioPlayer.pushReceiveAudioData(data: resultData, dataLen: resultData.count)
            }
            
            self.audioPlayer.startPlaying()
        }
        
        if let audioData = audioExtractor.extractDataFromAudioFile(at: fileUrl) {
            convert(audioData)
        } else {
            audioExtractor.convertWavToData(at: fileUrl) { data in
                if let audioData = data {
                    convert(audioData)
                    print("Test data: \(audioData)")
                } else {
                    print("Failed to extract audio data")
                }
            }
        }
    }
    
    func extractDataToFile(from data: Data, to fileUrl: URL) {
        do {
            try data.write(to: fileUrl)
            print("write success")
        } catch {
            print("write failure")
        }
    }
}
