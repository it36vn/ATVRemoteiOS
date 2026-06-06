import Foundation

extension CommandNetwork {
    struct VoiceBegin: RequestDataProtocol {
        let sessionID: Int

        var data: Data {
            var body = Data([0x08])
            body.append(contentsOf: Encoder.encodeVarint(UInt(sessionID)))
            return RemoteVoiceMessage.fieldData(fieldNumber: 30, body: body)
        }
    }

    struct VoicePayload: RequestDataProtocol {
        let sessionID: Int
        let samples: Data

        var data: Data {
            var body = Data([0x08])
            body.append(contentsOf: Encoder.encodeVarint(UInt(sessionID)))
            body.append(0x12)
            body.append(contentsOf: Encoder.encodeVarint(UInt(samples.count)))
            body.append(samples)
            return RemoteVoiceMessage.fieldData(fieldNumber: 31, body: body)
        }
    }

    struct VoiceEnd: RequestDataProtocol {
        let sessionID: Int

        var data: Data {
            var body = Data([0x08])
            body.append(contentsOf: Encoder.encodeVarint(UInt(sessionID)))
            return RemoteVoiceMessage.fieldData(fieldNumber: 32, body: body)
        }
    }

    enum RemoteVoiceMessage {
        static let preferredSampleRate: Double = 8_000
        static let preferredChunkSize = 20 * 1024
        static let minimumChunkSize = 8 * 1024

        static func fieldData(fieldNumber: UInt, body: Data) -> Data {
            var data = Data(Encoder.encodeVarint((fieldNumber << 3) | 2))
            data.append(contentsOf: Encoder.encodeVarint(UInt(body.count)))
            data.append(body)
            return data
        }

        static func extractBeginSessionID(from framedData: Data) -> Int? {
            extractSessionID(from: framedData, fieldNumber: 30)
        }

        static func extractEndSessionID(from framedData: Data) -> Int? {
            extractSessionID(from: framedData, fieldNumber: 32)
        }

        private static func extractSessionID(from framedData: Data, fieldNumber: UInt) -> Int? {
            guard let frame = protobufFrame(from: framedData),
                  let outerTag = Decoder.decodeVarint(frame),
                  outerTag.value == ((fieldNumber << 3) | 2) else {
                return nil
            }

            let outerLengthStart = outerTag.bytesCount
            guard let outerLength = Decoder.decodeVarint(Array(frame.dropFirst(outerLengthStart))) else {
                return nil
            }

            let bodyStart = outerLengthStart + outerLength.bytesCount
            let bodyEnd = bodyStart + Int(outerLength.value)
            guard frame.count >= bodyEnd else { return nil }

            let body = Array(frame[bodyStart..<bodyEnd])
            guard body.first == 0x08,
                  let session = Decoder.decodeVarint(Array(body.dropFirst())) else {
                return nil
            }

            return Int(session.value)
        }

        private static func protobufFrame(from data: Data) -> [UInt8]? {
            let bytes = Array(data)
            guard let length = Decoder.decodeVarint(bytes) else { return nil }
            let start = length.bytesCount
            let end = start + Int(length.value)
            guard bytes.count >= end else { return nil }
            return Array(bytes[start..<end])
        }
    }
}
