import Foundation
import AVFoundation
import Combine

class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var downloadedSounds: [SoundFile] = []
    @Published var isDownloading = false
    @Published var downloadProgress: String = ""
    @Published var selectedSoundName: String = ""

    private var player: AVAudioPlayer?
    private var retainedPlayer : AVAudioPlayer?
    private let soundsDir: URL
    private let defaults = UserDefaults.standard

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        soundsDir = appSupport.appendingPathComponent("MeetingAlarm/Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        loadSoundList()
        selectedSoundName = defaults.string(forKey: "selectedSound") ?? ""
    }

    // MARK: - Download via yt-dlp

    func downloadFromYouTube(url: String, customName: String, completion: @escaping (Bool, String) -> Void) {
        guard !url.isEmpty else {
            completion(false, "URL을 입력해주세요")
            return
        }

        // Check yt-dlp
        let ytdlpPath = findYtDlp()
        guard let ytdlp = ytdlpPath else {
            completion(false, "yt-dlp가 설치되어 있지 않습니다.\n터미널에서: brew install yt-dlp")
            return
        }

        isDownloading = true
        downloadProgress = "다운로드 중..."

        let name = customName.isEmpty ? "sound_\(Int(Date().timeIntervalSince1970))" : customName
        let outputTemplate = soundsDir.appendingPathComponent("\(name).%(ext)s").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlp)
        process.arguments = [
            url,
            "--extract-audio",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "--ffmpeg-location", "/opt/homebrew/bin/ffmpeg",
            "--output", outputTemplate,
            "--no-playlist"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let output = String(data: handle.availableData, encoding: .utf8) ?? ""
            if !output.isEmpty {
                DispatchQueue.main.async {
                    self?.downloadProgress = output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.isDownloading = false
                if proc.terminationStatus == 0 {
                    self?.loadSoundList()
                    completion(true, "\(name).mp3 다운로드 완료!")
                } else {
                    completion(false, "실패 (code: \(proc.terminationStatus)) \(self?.downloadProgress ?? "")")
                }
            }
        }

        DispatchQueue.global().async {
            try? process.run()
            process.waitUntilExit()
        }
    }
    
    func selectedSoundDuration() -> Int {
        guard !selectedSoundName.isEmpty else { return 10 }
        let fileURL = soundsDir.appendingPathComponent(selectedSoundName)
        guard let player = try? AVAudioPlayer(contentsOf: fileURL) else { return 10 }
        return Int(player.duration)
    }

    // MARK: - Playback

    func playAlarm() {
        guard !selectedSoundName.isEmpty else { return }
        let fileURL = soundsDir.appendingPathComponent(selectedSoundName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let p = try AVAudioPlayer(contentsOf: fileURL)
            retainedPlayer = p
            player = p
            p.prepareToPlay()
            p.play()
        } catch {
            print("재생 오류: \(error)")
        }
    }

    func previewSound(name: String) {
        let fileURL = soundsDir.appendingPathComponent(name)
        do {
            let p = try AVAudioPlayer(contentsOf: fileURL)
            retainedPlayer = p
            player = p
            p.prepareToPlay()
            player?.play()
        } catch {}
    }

    func stopPreview() {
        player?.stop()
    }

    func selectSound(_ name: String) {
        selectedSoundName = name
        defaults.set(name, forKey: "selectedSound")
    }

    func deleteSound(_ name: String) {
        let fileURL = soundsDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: fileURL)
        loadSoundList()
        if selectedSoundName == name {
            selectedSoundName = ""
            defaults.set("", forKey: "selectedSound")
        }
    }

    // MARK: - Helpers

    func loadSoundList() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: soundsDir.path)) ?? []
        downloadedSounds = files
            .filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".m4a") || $0.hasSuffix(".wav") }
            .map { SoundFile(name: $0) }
            .sorted { $0.name < $1.name }
    }

    private func findYtDlp() -> String? {
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}

struct SoundFile: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var displayName: String { name.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".wav", with: "").replacingOccurrences(of: ".m4a", with: "") }
}
