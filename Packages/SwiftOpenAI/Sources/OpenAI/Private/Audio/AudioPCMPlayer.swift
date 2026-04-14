//
//  AudioPCMPlayer.swift
//  SwiftOpenAI
//
//  Created from AIProxySwift
//  Original: https://github.com/lzell/AIProxySwift
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.swiftopenai", category: "Audio")

// MARK: - AudioPCMPlayer

/// # Warning
/// The order that you initialize `AudioPCMPlayer()` and `MicrophonePCMSampleVendor()` matters, unfortunately.
///
/// The voice processing audio unit on iOS has a volume bug that is not present on macOS.
/// The volume of playback depends on the initialization order of AVAudioEngine and the `kAudioUnitSubType_VoiceProcessingIO` Audio Unit.
/// We use AudioEngine for playback in this file, and the voice processing audio unit in MicrophonePCMSampleVendor.
///
/// I find the best result to be initializing `AudioPCMPlayer()` first. Otherwise, the playback volume is too quiet on iOS.
@RealtimeActor
final class AudioPCMPlayer {

  init(audioEngine: AVAudioEngine) async throws {
    self.audioEngine = audioEngine
    guard
      let inputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true)
    else {
      throw AudioPCMPlayerError.couldNotConfigureAudioEngine(
        "Could not create input format for AudioPCMPlayer")
    }

    guard
      let playableFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24000,
        channels: 1,
        interleaved: true)
    else {
      throw AudioPCMPlayerError.couldNotConfigureAudioEngine(
        "Could not create playback format for AudioPCMPlayer")
    }

    let node = AVAudioPlayerNode()

    audioEngine.attach(node)
    // Connect through mainMixerNode instead of directly to outputNode.
    // When voice processing is enabled on the input node, a direct
    // connection to outputNode can cause sample rate conversion issues.
    audioEngine.connect(node, to: audioEngine.mainMixerNode, format: playableFormat)

    playerNode = node
    self.inputFormat = inputFormat
    self.playableFormat = playableFormat
  }

  deinit {
    logger.debug("AudioPCMPlayer is being freed")
  }

  /// The number of audio buffers currently scheduled but not yet finished playing.
  public private(set) var pendingBufferCount: Int = 0

  /// Called on the RealtimeActor when the last pending buffer finishes playing.
  public var onPlaybackDrained: (() -> Void)?

  // MARK: - Initial Buffering
  // Accumulate the first few audio chunks as raw PCM16 data and merge into a
  // single continuous AVAudioPCMBuffer before scheduling playback. This matches
  // the approach used by official GLM SDKs (pcm-player flushTime: 500ms,
  // realtime-front 200KB accumulation) and eliminates micro-gaps between tiny
  // individually-scheduled buffers that cause clicking/beeping artifacts.

  /// Accumulated raw PCM16 data waiting to be flushed as a single buffer.
  private var accumulatedPCMData = Data()
  /// Whether initial buffering has completed and playback has started.
  private var hasStartedPlayback: Bool = false
  /// Byte threshold before flushing initial buffer (~500ms at 24kHz mono 16-bit).
  private let initialBufferThreshold: Int = 24_000

  public func playPCM16Audio(from base64String: String) {
    guard let audioData = Data(base64Encoded: base64String) else {
      logger.error("Could not decode base64 string for audio playback")
      return
    }

    if hasStartedPlayback {
      // After initial buffering, schedule each chunk immediately.
      // The player has a ~500ms head start so underruns are unlikely.
      if let buf = convertToPCM32(audioData: audioData) {
        scheduleBuffer(buf)
      }
    } else {
      // Accumulate raw PCM16 bytes; will be merged into one buffer on flush
      accumulatedPCMData.append(audioData)
      if accumulatedPCMData.count >= initialBufferThreshold {
        flushAccumulatedData()
      }
    }
  }

  /// Force-flush any accumulated audio data and start playback.
  /// Call this when the server signals no more audio is coming (response.audio.done)
  /// to handle responses shorter than the buffer threshold.
  public func flushBufferedAudio() {
    guard !hasStartedPlayback, !accumulatedPCMData.isEmpty else { return }
    flushAccumulatedData()
  }

  public func interruptPlayback() {
    // Clear any accumulated data that hasn't started playing yet
    accumulatedPCMData = Data()
    hasStartedPlayback = false

    guard pendingBufferCount > 0 else { return }
    logger.debug("Interrupting playback")
    playerNode.stop()
    pendingBufferCount = 0
  }

  // MARK: - Private Helpers

  private func convertToPCM32(audioData: Data) -> AVAudioPCMBuffer? {
    var bufferList = AudioBufferList(
      mNumberBuffers: 1,
      mBuffers:
      AudioBuffer(
        mNumberChannels: 1,
        mDataByteSize: UInt32(audioData.count),
        mData: UnsafeMutableRawPointer(mutating: (audioData as NSData).bytes)))

    guard
      let inPCMBuf = AVAudioPCMBuffer(
        pcmFormat: inputFormat,
        bufferListNoCopy: &bufferList)
    else {
      logger.error("Could not create input buffer for audio playback")
      return nil
    }

    guard
      let outPCMBuf = AVAudioPCMBuffer(
        pcmFormat: playableFormat,
        frameCapacity: AVAudioFrameCount(UInt32(audioData.count) * 2))
    else {
      logger.error("Could not create output buffer for audio playback")
      return nil
    }

    guard let converter = AVAudioConverter(from: inputFormat, to: playableFormat) else {
      logger.error("Could not create audio converter needed to map from pcm16int to pcm32float")
      return nil
    }

    do {
      try converter.convert(to: outPCMBuf, from: inPCMBuf)
    } catch {
      logger.error("Could not map from pcm16int to pcm32float: \(error.localizedDescription)")
      return nil
    }

    return outPCMBuf
  }

  private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
    guard audioEngine.isRunning else { return }
    pendingBufferCount += 1
    playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
      Task { @RealtimeActor [weak self] in
        guard let self else { return }
        self.pendingBufferCount -= 1
        if self.pendingBufferCount <= 0 {
          self.pendingBufferCount = 0
          self.hasStartedPlayback = false
          self.onPlaybackDrained?()
        }
      }
    }
    if !playerNode.isPlaying {
      playerNode.play()
    }
  }

  /// Merge all accumulated raw PCM16 data into a single continuous buffer
  /// and schedule it for playback. This avoids micro-gaps between small buffers.
  private func flushAccumulatedData() {
    let byteCount = accumulatedPCMData.count
    guard byteCount > 0 else { return }
    logger.debug("Flushing \(byteCount) bytes of accumulated PCM16 as single buffer")
    if let buf = convertToPCM32(audioData: accumulatedPCMData) {
      scheduleBuffer(buf)
    }
    accumulatedPCMData = Data()
    hasStartedPlayback = true
  }

  let audioEngine: AVAudioEngine

  private let inputFormat: AVAudioFormat
  private let playableFormat: AVAudioFormat
  private let playerNode: AVAudioPlayerNode

}
#endif
