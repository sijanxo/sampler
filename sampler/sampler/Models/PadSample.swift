//
//  PadSample.swift
//  sampler
//
//  Created by Sijan Khadka on 27/11/2025.
//


import Foundation
import AVFoundation

struct PadSample: Identifiable {
    let id = UUID()
    let fileURL: URL
    let duration: TimeInterval
    // We'll keep the buffer lazy-loaded if needed later
}