//
//  PreprocessAudio.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import Foundation
import OnnxWrapper

class PreprocessAudio {
    private let ortEnv: ORTEnv
    
    private let ortSession1: ORTSession
    
    private let ortSession2: ORTSession
    
    private var ortValue1: ORTValue
    
    private var ortValue2: ORTValue
    
    private let session1Shape: [NSNumber] = [1, 2, 128, 2] // session1Shape2 로 되어있음
    
    private let session2Shape: [NSNumber] = [1, 2, 128, 2] // session2Shape2 로 되어있음
    
    func inferSession1(_ inputData: Data) throws -> Data {
        // Android 에서 inputData는 FloatArray 257의 크기인것으로 입력 받는다.
        let inputShape: [NSNumber] = [1, 1, inputData.count / MemoryLayout<Float>.stride as NSNumber]
        let input = try ORTValue(
            tensorData: NSMutableData(data: inputData),
            elementType: ORTTensorElementDataType.float,
            shape: inputShape
        )
        let startTime = DispatchTime.now()
        let outputs = try ortSession1.run(
            withInputs: ["input_2": input, "input_3": ortValue1],
            outputNames: ["activation_2", "tf_op_layer_stack_2"],
            runOptions: nil
        )
        let endTime = DispatchTime.now()
        print("ORT session run time: \(Float(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1.0e6) ms")
        guard
            let output1 = outputs["activation_2"],
            let output2 = outputs["tf_op_layer_stack_2"]
        else {
            throw PreprocessAudioError.Error("Failed to get model output.")
        }
        ortValue1 = try ORTValue(tensorData: output2.tensorData(), elementType: ORTTensorElementDataType.float, shape: session1Shape)
        let outputData = try output1.tensorData() as Data
        return outputData
    }
    
    func inferSession2(_ inputData: Data) throws -> Data {
        // Android 에서 inputData는 FloatArray 512의 크기인것으로 입력 받는다.
        let inputShape: [NSNumber] = [1, 1, inputData.count / MemoryLayout<Float>.stride as NSNumber] // session2Shape1로 되어있음
        let input = try ORTValue(
            tensorData: NSMutableData(data: inputData),
            elementType: ORTTensorElementDataType.float,
            shape: inputShape
        )
        let startTime = DispatchTime.now()
        let outputs = try ortSession2.run(
            withInputs: ["input_4": input, "input_5": ortValue2],
            outputNames: ["conv1d_3", "tf_op_layer_stack_5"],
            runOptions: nil
        )
        let endTime = DispatchTime.now()
        print("ORT session run time: \(Float(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1.0e6) ms")
        guard
            let output1 = outputs["conv1d_3"],
            let output2 = outputs["tf_op_layer_stack_5"]
        else {
          throw PreprocessAudioError.Error("Failed to get model output.")
        }
        ortValue2 = try ORTValue(tensorData: output2.tensorData(), elementType: ORTTensorElementDataType.float, shape: session2Shape)
        let outputData = try output1.tensorData() as Data
        return outputData
    }
    
    init() throws {
        let options = try ORTSessionOptions()
        ortEnv = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
        guard
            let model1Path = Bundle.main.path(forResource: "dnn_model_1", ofType: "onnx"),
            let model2Path = Bundle.main.path(forResource: "dnn_model_2", ofType: "onnx")
        else {
          throw PreprocessAudioError.Error("Failed to find model file.")
        }
        ortSession1 = try ORTSession(env: ortEnv, modelPath: model1Path, sessionOptions: options)
        ortSession2 = try ORTSession(env: ortEnv, modelPath: model2Path, sessionOptions: options)
        let zeros1 = Data(count: session1Shape.reduce(1) { acc, i in acc * Int(truncating: i) * MemoryLayout<Float>.stride })
        let zeros2 = Data(count: session2Shape.reduce(1) { acc, i in acc * Int(truncating: i) * MemoryLayout<Float>.stride })
        ortValue1 = try ORTValue(tensorData: NSMutableData(data: zeros1), elementType: ORTTensorElementDataType.float, shape: session1Shape)
        ortValue2 = try ORTValue(tensorData: NSMutableData(data: zeros2), elementType: ORTTensorElementDataType.float, shape: session2Shape)
    }
    
    enum PreprocessAudioError: Error {
      case Error(_ message: String)
    }
}
