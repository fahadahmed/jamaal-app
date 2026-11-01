// Encodes numbered PNG frames (1080x1920) into an H.264 mp4, no audio.
// Usage: swift encode.swift <frames-dir> <out.mp4> [fps]
import AVFoundation
import AppKit

let args = CommandLine.arguments
let dir = args[1], out = args[2]
let fps: Int32 = args.count > 3 ? Int32(args[3])! : 30
let (w, h) = (1080, 1920)
let url = URL(fileURLWithPath: out)
try? FileManager.default.removeItem(at: url)

let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let files = try FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".png") }.sorted()
for (i, f) in files.enumerated() {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    guard let image = NSImage(contentsOfFile: dir + "/" + f),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("cannot read \(f)") }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    CVPixelBufferLockBaseAddress(buffer!, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer!), width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    CVPixelBufferUnlockBaseAddress(buffer!, [])
    adaptor.append(buffer!, withPresentationTime: CMTime(value: Int64(i), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { print("failed:", writer.error as Any); exit(1) }
print("wrote \(files.count) frames to \(out)")
