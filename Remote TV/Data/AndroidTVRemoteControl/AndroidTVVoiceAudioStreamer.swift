import AVFoundation
import Foundation

final class AndroidTVVoiceAudioStreamer {
    enum StreamError: Error {
        case microphonePermissionDenied
        case audioFormatUnavailable
    }

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "androidtv.voice.audio")
    private let onChunk: (Data) -> Void
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var pendingSamples = Data()
    private var isStreaming = false

    init(onChunk: @escaping (Data) -> Void) {
        self.onChunk = onChunk
    }

    func start() async throws {
        guard await requestMicrophonePermission() else {
            throw StreamError.microphonePermissionDenied
        }

        try await MainActor.run {
            try configureAndStartEngine()
        }
    }

    func stop() {
        guard isStreaming else { return }
        isStreaming = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        processingQueue.async { [weak self] in
            guard let self else { return }
            if !self.pendingSamples.isEmpty {
                self.onChunk(self.paddedChunk(self.pendingSamples))
                self.pendingSamples.removeAll()
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await AVAudioApplication.requestRecordPermission()
            @unknown default:
                return false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        }
    }

    @MainActor
    private func configureAndStartEngine() throws {
        if isStreaming { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: [])

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: CommandNetwork.RemoteVoiceMessage.preferredSampleRate,
            channels: 1,
            interleaved: true
        ), let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw StreamError.audioFormatUnavailable
        }

        self.converter = converter
        self.outputFormat = targetFormat
        pendingSamples.removeAll()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        try engine.start()
        isStreaming = true
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        processingQueue.async { [weak self] in
            guard let self, self.isStreaming else { return }
            guard let converted = self.convert(buffer), let data = self.data(from: converted) else { return }

            self.pendingSamples.append(data)
            while self.pendingSamples.count >= CommandNetwork.RemoteVoiceMessage.preferredChunkSize {
                let chunk = self.pendingSamples.prefix(CommandNetwork.RemoteVoiceMessage.preferredChunkSize)
                self.onChunk(Data(chunk))
                self.pendingSamples.removeFirst(CommandNetwork.RemoteVoiceMessage.preferredChunkSize)
            }
        }
    }

    private func convert(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter, let outputFormat else { return nil }

        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 1
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var didProvideInput = false
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            status.pointee = .haveData
            return inputBuffer
        }

        return error == nil ? outputBuffer : nil
    }

    private func data(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else { return nil }
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: channelData[0], count: byteCount)
    }

    private func paddedChunk(_ data: Data) -> Data {
        guard data.count < CommandNetwork.RemoteVoiceMessage.minimumChunkSize else { return data }
        var padded = data
        padded.append(Data(repeating: 0, count: CommandNetwork.RemoteVoiceMessage.minimumChunkSize - data.count))
        return padded
    }
}
