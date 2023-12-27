//
//  ContentView.swift
//  DTLNSampleApp
//
//  Created by 홍희표 on 2023/12/27.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel = ContentViewModel()
    
    var body: some View {
        VStack(spacing: 10) {
            Button(action: viewModel.playOriginalAudioFile) {
                Text("원본 음성파일 재생")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .padding(10)
            Button(action: viewModel.playAppliedDTLNAudioFile) {
                Text("잡음 억제 변환음성 재생")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .padding(10)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
