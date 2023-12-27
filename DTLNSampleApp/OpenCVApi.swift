//
//  OpenCVApi.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import Foundation
import opencv2

func openCVTest() throws {
    var tmp: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    var data = tmp
    var rows: Int32 = 1
    var cols = Int32(data.count)
    var dataType = CvType.CV_32F
    print("TestDTLNModule ===== inputData.size = \(data.count)")
    var test = Mat(rows: rows, cols: cols, type: dataType)
    try test.put(row: 0, col: 0, data: data)
    var result = Mat()
    Core.dft(src: test, dst: result, flags: DftFlags.DFT_ROWS.rawValue | DftFlags.DFT_COMPLEX_OUTPUT.rawValue)
    print("TestDTLNModule ===== Result Matrix \(result.rows()) x \(result.cols()) x \(result.channels())")
    for i: Int32 in 0..<10 {
        var item1 = result.get(row: 0, col: i)[0]
        var item2 = result.get(row: 0, col: i)[1]
        print("TestDTLNModule \(i) : \(item1) \(item2)")
    }
    var matList: [Mat] = []
    Core.split(m: result, mv: &matList)
    var mag = Mat()
    var phase = Mat()
    Core.cartToPolar(x: matList[0], y: matList[1], magnitude: mag, angle: phase)
    print("TestDTLNModule ===== Mag Matrix \(mag.rows()) x \(mag.cols()) x \(mag.channels())")
    print("TestDTLNModule ===== Phase Matrix \(phase.rows()) x \(phase.cols()) x \(phase.channels())")
    for i: Int32 in 0..<10 {
        var item1 = mag.get(row: 0, col: i)[0]
        var item2 = phase.get(row: 0, col: i)[0]
        print("TestDTLNModule === Mag \(item1), phase \(item2)")
    }
    // Inverse
    var realPart = Mat()
    var imaginaryPart = Mat()
    Core.polarToCart(magnitude: mag, angle: phase, x: realPart, y: imaginaryPart)
    print("TestDTLNModule ===== realPart Matrix \(realPart.rows()) x \(realPart.cols()) x \(realPart.channels())")
    print("TestDTLNModule ===== imaginaryPart Matrix \(imaginaryPart.rows()) x \(imaginaryPart.cols()) x \(imaginaryPart.channels())")
    matList[0] = realPart
    matList[1] = imaginaryPart
    Core.merge(mv: matList, dst: result)
    var recoveredResult = Mat()
    Core.idft(src: result, dst: recoveredResult, flags: DftFlags.DFT_ROWS.rawValue | DftFlags.DFT_REAL_OUTPUT.rawValue | DftFlags.DFT_SCALE.rawValue)
    print("TestDTLNModule ===== recoveredResult Matrix \(recoveredResult.rows()) x \(recoveredResult.cols()) x \(recoveredResult.channels())")
    for i: Int32 in 0..<10 {
        var item = recoveredResult.get(row: 0, col: i)[0]
        print("TestDTLNModule === recoveredResult \(item)")
    }
}

func getMagPhase(inputData: [Float], outputMag: inout [Float], outputPhase: inout [Float]) throws {
    var inputMag = Mat(rows: 1, cols: Int32(inputData.count), type: CvType.CV_32F)
    try inputMag.put(row: 0, col: 0, data: inputData)
    var result = Mat()
    Core.dft(src: inputMag, dst: result, flags: DftFlags.DFT_ROWS.rawValue | DftFlags.DFT_COMPLEX_OUTPUT.rawValue)
    var matList: [Mat] = []
    Core.split(m: result, mv: &matList)
    var mag = Mat()
    var phase = Mat()
    Core.cartToPolar(x: matList[0], y: matList[1], magnitude: mag, angle: phase)
    try mag.get(row: 0, col: 0, data: &outputMag)
    try phase.get(row: 0, col: 0, data: &outputPhase)
}

func getWave(inputMag: [Float], maskMag: [Float], noiseOut: Bool, inputPhase: [Float], outputWave: inout [Float]) throws {
    var maskMagI = 0
    for i in inputMag.indices {
        maskMagI = i > inputMag.count / 2 ? inputMag.count - i : i
        if noiseOut {
            outputWave[i] = inputMag[i] * (1.0 - maskMag[maskMagI])
        } else {
            outputWave[i] = inputMag[i] * maskMag[maskMagI]
        }
    }
    var cols: Int32 = Int32(inputMag.count)
    var dataType = CvType.CV_32F
    var mag = Mat(rows: 1, cols: cols, type: dataType)
    try mag.put(row: 0, col: 0, data: outputWave)
    var phase = Mat(rows: 1, cols: cols, type: dataType)
    try phase.put(row: 0, col: 0, data: inputPhase)
    
    var realPart = Mat()
    var imaginaryPart = Mat()
    Core.polarToCart(magnitude: mag, angle: phase, x: realPart, y: imaginaryPart)
    var matList = [Mat]()
    matList.append(realPart)
    matList.append(imaginaryPart)
    var result = Mat()
    Core.merge(mv: matList, dst: result)
    var recoveredResult = Mat()
    Core.idft(src: result, dst: recoveredResult, flags: DftFlags.DFT_ROWS.rawValue | DftFlags.DFT_REAL_OUTPUT.rawValue | DftFlags.DFT_SCALE.rawValue)
    try recoveredResult.get(row: 0, col: 0, data: &outputWave)
}
