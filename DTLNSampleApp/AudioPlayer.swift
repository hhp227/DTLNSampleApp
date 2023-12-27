//
//  AudioPlayer.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import Foundation
import AVFoundation

class AudioPlayer {
    private static let AUDIO_CHANNEL = 1
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private var audioPlayer: AVAudioPlayer?
    
    private let audioPlayerLock = NSLock()
    
    private var recvFormat = AudioStreamBasicDescription()
    
    private var soundDataBufferQueue = Data()
    
    private let kInputBus = AudioUnitElement(1)
    
    private let kOutputBus = AudioUnitElement(0)
    
    private var enableOutput: UInt32 = 1
    
    private var audioUnit: AudioUnit! = nil
    
    private var audioCompoDesc = AudioComponentDescription()
    
    private var audioComponent: AudioComponent?
    
    private lazy var outputCallbackStruct = AURenderCallbackStruct(
        inputProc: onOutputCallback,
        inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
    )
    
    private var onOutputCallback: AURenderCallback = { (inRefCon, _, _, _, inNumberFrame, ioData) -> OSStatus in
        let player = Unmanaged<AudioPlayer>.fromOpaque(inRefCon).takeUnretainedValue()
        var totalFrameBytes = Int(inNumberFrame) * 2 * AUDIO_CHANNEL // 2byte, 2channel

        player.audioPlayerLock.lock()
        defer {
            player.audioPlayerLock.unlock()
        }

        if player.soundDataBufferQueue.count < totalFrameBytes {
            var buffer: AudioBuffer = (ioData?.pointee.mBuffers)!
            memset(buffer.mData, 0, totalFrameBytes)
        }
        else {
            player.soundDataBufferQueue.withUnsafeMutableBytes { ptr in
                if let rawPtr = ptr.baseAddress,
                   var buffer = ioData?.pointee.mBuffers {
                    buffer.mData?.copyMemory(from: rawPtr, byteCount: totalFrameBytes)
                    buffer.mDataByteSize = UInt32(totalFrameBytes)
                    buffer.mNumberChannels = UInt32(AUDIO_CHANNEL)
                }
            }
            if totalFrameBytes < player.soundDataBufferQueue.count - 1 {
                player.soundDataBufferQueue.removeFirst(totalFrameBytes)
            } else {
                player.soundDataBufferQueue.removeAll()
            }
        }
        return noErr
    }

    private func setAudioUnit(audioPropertyId: UInt32) {
        audioCompoDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: audioPropertyId,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        audioComponent = AudioComponentFindNext(nil, &audioCompoDesc)!
        
        AudioComponentInstanceNew(audioComponent!, &audioUnit)

        // 장치 출력 설정
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            kOutputBus,
            &enableOutput,
            UInt32(MemoryLayout.size(ofValue: enableOutput))
        )

        recvFormat.mSampleRate = Float64(16000)
        recvFormat.mFormatID = kAudioFormatLinearPCM
        recvFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        recvFormat.mChannelsPerFrame = UInt32(AudioPlayer.AUDIO_CHANNEL)
        recvFormat.mFramesPerPacket = 1
        recvFormat.mBitsPerChannel = UInt32(16);   // 16bit sampling
        recvFormat.mBytesPerPacket = (UInt32(16) >> 3) * recvFormat.mChannelsPerFrame
        recvFormat.mBytesPerFrame = (UInt32(16) >> 3) * recvFormat.mChannelsPerFrame
        recvFormat.mReserved = 0

        // 스트림 포맷 설정
        AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            kOutputBus,
            &recvFormat,
            UInt32(MemoryLayout.size(ofValue: recvFormat))
        )

        // 콜백 설정
        AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            kOutputBus,
            &outputCallbackStruct,
            UInt32(MemoryLayout.size(ofValue: outputCallbackStruct))
        )
        AudioUnitInitialize(audioUnit)
    }
    
    func playAudioFile(from fileUrl: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileUrl)
            
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play audio file: \(error.localizedDescription)")
        }
    }
    
    func playAudioData(data audioData: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio data: \(error.localizedDescription)")
        }
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        do {
            // Deactivate audio session
            try audioSession.setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    func pushReceiveAudioData(data: Data, dataLen: Int) {
        audioPlayerLock.lock()
        self.soundDataBufferQueue.append(data)
        audioPlayerLock.unlock()
    }
    
    func startPlaying() {
        audioPlayerLock.lock()
        soundDataBufferQueue.removeAll()
        audioPlayerLock.unlock()
    }

    func stopPlaying() {
        audioPlayerLock.lock()
        soundDataBufferQueue.removeAll()
        audioPlayerLock.unlock()
    }
    
    init() {
        try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .allowBluetooth])
        try? audioSession.setPreferredIOBufferDuration(0.01)
        setAudioUnit(audioPropertyId: kAudioUnitSubType_VoiceProcessingIO)
        AudioOutputUnitStart(audioUnit)
    }
    
    deinit {
        AudioOutputUnitStop(audioUnit)
        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
        try? audioSession.setActive(false)
    }
}
