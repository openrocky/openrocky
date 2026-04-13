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
  // Accumulate the first few audio chunks before starting playback to prevent
  // buffer underruns that cause clicking/beeping artifacts. Once enough data is
  // buffered, all accumulated chunks are scheduled at once for gapless playback.

  /// Accumulated PCM buffers waiting to be flushed.
  private var accumulatedBuffers: [AVAudioPCMBuffer] = []
  /// Total raw byte count of accumulated audio data.
  private var accumulatedByteCount: Int = 0
  /// Whether initial buffering has completed and playback has started.
  private var hasStartedPlayback: Bool = false
  /// Byte threshold before flushing initial buffer (~300ms at 24kHz mono 16-bit).
  private let initialBufferThreshold: Int = 14_400

  public func playPCM16Audio(from base64String: String) {
    guard let audioData = Data(base64Encoded: base64String) else {
      logger.error("Could not decode base64 string for audio playback")
      return
    }

    guard let outPCMBuf = convertToPCM32(audioData: audioData) else { return }

    if hasStartedPlayback {
      scheduleBuffer(outPCMBuf)
    } else {
      accumulatedBuffers.append(outPCMBuf)
      accumulatedByteCount += audioData.count
      if accumulatedByteCount >= initialBufferThreshold {
        flushAccumulatedBuffers()
      }
    }
  }

  /// Force-flush any accumulated audio buffers and start playback.
  /// Call this when the server signals no more audio is coming (response.audio.done)
  /// to handle responses shorter than the buffer threshold.
  public func flushBufferedAudio() {
    guard !hasStartedPlayback, !accumulatedBuffers.isEmpty else { return }
    flushAccumulatedBuffers()
  }

  public func interruptPlayback() {
    // Clear any accumulated buffers that haven't started playing yet
    accumulatedBuffers.removeAll()
    accumulatedByteCount = 0
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

  private func flushAccumulatedBuffers() {
    logger.debug("Flushing \(self.accumulatedBuffers.count) buffered audio chunks (\(self.accumulatedByteCount) bytes)")
    for buffer in accumulatedBuffers {
      scheduleBuffer(buffer)
    }
    accumulatedBuffers.removeAll()
    accumulatedByteCount = 0
    hasStartedPlayback = true
  }

  let audioEngine: AVAudioEngine

  private let inputFormat: AVAudioFormat
  private let playableFormat: AVAudioFormat
  private let playerNode: AVAudioPlayerNode

}
#endif
