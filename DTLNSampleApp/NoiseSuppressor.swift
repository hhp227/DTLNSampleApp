//
//  NoiseSuppressor.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import Foundation

class NoiseSuppressor {
    private var audioPreprocess: PreprocessAudio = try! PreprocessAudio()
    
    private var remainData = Data(capacity: 128)
    
    private var blockShift = 128
    
    private var blockLen = 512
    
    private var blockLenHalf = 257
    
    private lazy var inBuffer = [Float](repeating: 0, count: blockLen)
    
    private lazy var outputMag = [Float](repeating: 0, count: blockLen)
    
    private lazy var outputPhase = [Float](repeating: 0, count: blockLen)
    
    private lazy var outputSession1 = [Float](repeating: 0, count: blockLenHalf)
    
    private lazy var estimated = [Float](repeating: 0, count: blockLen)
    
    private lazy var outputSession2 = [Float](repeating: 0, count: blockLen)
    
    private lazy var outBuffer = [Float](repeating: 0, count: blockLen)
    
    private lazy var outBufferShort = [Int16](repeating: 0, count: blockLen)
    
    private var noiseOut = false
    
    private var lowLimit = Int16.min
    
    private var highLimit = Int16.max
    
    private func setBuffersInit() {
        inBuffer = [Float](repeating: 0, count: blockLen)
        outputMag = [Float](repeating: 0, count: blockLen)
        outputPhase = [Float](repeating: 0, count: blockLen)
        outputSession1 = [Float](repeating: 0, count: blockLenHalf)
        estimated = [Float](repeating: 0, count: blockLen)
        outputSession2 = [Float](repeating: 0, count: blockLen)
        outBuffer = [Float](repeating: 0, count: blockLen)
        outBufferShort = [Int16](repeating: 0, count: blockLen)
        
        if !remainData.isEmpty {
            remainData.removeAll()
        }
    }
    
    private func convertShorts2Bytes(input: [Int16]) -> [UInt8] {
        var shortIndex = 0
        var byteIndex = 0
        var buffer = [UInt8](repeating: 0, count: input.count * 2)
        
        while shortIndex != input.count {
            buffer[byteIndex] = UInt8(truncatingIfNeeded: input[shortIndex] & 0x00FF)
            buffer[byteIndex + 1] = UInt8(truncatingIfNeeded: (input[shortIndex] >> 8) & 0xff)
            shortIndex += 1
            byteIndex += 2
        }
        return buffer
    }
    
    private func convertData2Array(audioData: Data) -> [Data] {
        var splittedDatas = [Data]()
        var returnDatas = [Data]()
        
        for i in 0...(audioData.count / 128) - 1 {
            let splitData = audioData[i * 128..<(i + 1) * 128]
            
            splittedDatas.append(splitData)
            if !remainData.isEmpty && i == 0 {
                returnDatas.append(remainData + splittedDatas[0])
                splittedDatas.removeAll()
            }
            if splittedDatas.count == 2 {
                returnDatas.append(splittedDatas[0] + splittedDatas[1])
                splittedDatas.removeAll()
            }
            if i == (audioData.count / 128) - 1 {
                if splittedDatas.count == 1 {
                    remainData.append(contentsOf: splittedDatas[0])
                } else {
                    remainData.removeAll()
                }
            }
        }
        return returnDatas
    }
    
    private func getNoiseCanceledData(data: Data) -> Data {
        var returnData = Data()
        let buffer = data
        var floatsData = [Float](repeating: 0, count: blockShift)
        
        for i in 0..<blockShift {
            floatsData[i] = Float(buffer.withUnsafeBytes { $0.load(fromByteOffset: i * 2, as: Int16.self) }) / Float(highLimit)
        }
        let shiftedInBuffer = inBuffer[blockShift..<blockLen]
        inBuffer = shiftedInBuffer + floatsData
        try? getMagPhase(inputData: inBuffer, outputMag: &outputMag, outputPhase: &outputPhase)
        let sliced = Array(outputMag[0..<blockLenHalf])
        outputSession1 = try! audioPreprocess.inferSession1(Data(bytes: sliced, count: MemoryLayout<Float>.size * sliced.count)).withUnsafeBytes {
            let count = $0.count / MemoryLayout<Float>.stride
            return $0.bindMemory(to: Float.self).prefix(count).map { $0 }
        }
        try? getWave(inputMag: outputMag, maskMag: outputSession1, noiseOut: noiseOut, inputPhase: outputPhase, outputWave: &estimated)
        outputSession2 = try! audioPreprocess.inferSession2(Data(bytes: estimated, count: MemoryLayout<Float>.size * estimated.count)).withUnsafeBytes {
            let count = $0.count / MemoryLayout<Float>.stride
            return $0.bindMemory(to: Float.self).prefix(count).map { $0 }
        }
        let shiftedOutBuffer = outBuffer[blockShift..<blockLen]
        outBuffer = shiftedOutBuffer + [Float](repeating: 0, count: blockShift)
        for i in outBuffer.indices {
            outBuffer[i] = outBuffer[i] + outputSession2[i]
            outBufferShort[i] = Int16(max(min(Int(outBuffer[i] * Float(Int16.max)), Int(Int16.max)), Int(Int16.min)))
        }
        returnData.append(Data(convertShorts2Bytes(input: outBufferShort)))
        return returnData
    }
    
    func convert(data: Data, complete: @escaping (Data) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let dataArray = self.convertData2Array(audioData: data)
            
            for data in dataArray {
                let noiseCanceledData = self.getNoiseCanceledData(data: data).subdata(in: 0..<256)
                
                complete(noiseCanceledData)
            }
        }
    }
}
