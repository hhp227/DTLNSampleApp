//
//  AudioExtractor.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import Foundation
import AVFoundation

class AudioExtractor {
    func extractDataFromAudioFile(at url: URL) -> Data? {
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            print("failure \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertWavToData(at url: URL, completion: @escaping (Data?) -> Void) {
        let asset = AVAsset(url: url)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            print("Failed to create AVAssetExportSession")
            completion(nil)
            return
        }
        exportSession.outputFileType = .wav
        exportSession.outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_output.wav")
        
        exportSession.exportAsynchronously {
            guard exportSession.status == .completed else {
                print("Failed to export m4a file")
                completion(nil)
                return
            }
        }
        do {
            let data = try Data(contentsOf: exportSession.outputURL!)
            
            completion(data)
        } catch {
            print("Failed to read data from output file")
            completion(nil)
        }
    }
}
