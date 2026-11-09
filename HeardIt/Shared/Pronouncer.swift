import AVFoundation

enum Dialect: String, CaseIterable {
    case mandarin, cantonese

    var languageCode: String { self == .mandarin ? "zh-CN" : "zh-HK" }
}

extension Word {
    /// The text to hand the speech voice for each dialect.
    /// Cantonese-only words speak their Mandarin equivalent for the Mandarin voice.
    func speechText(_ dialect: Dialect) -> String? {
        switch dialect {
        case .mandarin:
            if !pinyin.isEmpty { return simplified }
            guard let m = mandarinWord,
                  let range = m.range(of: "[\\u3400-\\u9fff]+", options: .regularExpression) else { return nil }
            return String(m[range])
        case .cantonese:
            return traditional
        }
    }
}

/// Says words aloud with Apple's on-device voices: Mandarin (zh-CN) and Cantonese (zh-HK).
/// Picks the best installed voice. Users can download Enhanced/Premium Chinese voices in
/// Settings > Accessibility > Spoken Content > Voices for a more natural sound.
@MainActor
final class Pronouncer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Pronouncer()

    private let synth = AVSpeechSynthesizer()
    private var lastUtterance: AVSpeechUtterance?
    private var finished: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synth.delegate = self
    }

    func bestVoice(_ dialect: Dialect) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == dialect.languageCode }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: dialect.languageCode)
    }

    /// Start speaking; returns false if there was nothing to say.
    @discardableResult
    func speak(_ word: Word, _ dialects: [Dialect]) -> Bool {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        lastUtterance = nil
        for dialect in dialects {
            guard let text = word.speechText(dialect) else { continue }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = bestVoice(dialect)
            utterance.rate = 0.42
            utterance.postUtteranceDelay = 0.3
            synth.speak(utterance)
            lastUtterance = utterance
        }
        return lastUtterance != nil
    }

    /// Speak and wait until finished (used by the widget's audio intent), with a safety timeout.
    func speakAndWait(_ word: Word, _ dialects: [Dialect]) async {
        finished?.resume()
        finished = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finished = continuation
            if !speak(word, dialects) {
                finished = nil
                continuation.resume()
                return
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self.finishIfWaiting()
            }
        }
    }

    private func finishIfWaiting() {
        finished?.resume()
        finished = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance === self.lastUtterance { self.finishIfWaiting() }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance === self.lastUtterance { self.finishIfWaiting() }
        }
    }
}
