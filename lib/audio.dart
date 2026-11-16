import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

// Time is counted in samples instead of with a clock: 16,000 samples are
// always exactly one second, so tests with made-up audio give the same result
// every time.

/// Samples per second. Whisper expects 16 kHz, one channel.
const sampleRate = 16000;

/// While someone is talking, emit what we have so far this often (~1 s).
const partialEverySamples = sampleRate;

/// This much silence in a row means the sentence is over (~600 ms).
const silenceToFinishSamples = sampleRate * 600 ~/ 1000;

/// A sentence is cut here even if the person never stops talking (12 s).
const maxChunkSamples = sampleRate * 12;

/// A block of audio counts as speech when its volume is at least this.
/// Volume goes from 0 (silence) to 1 (the loudest the mic can record).
final volumeThreshold = ValueNotifier<double>(0.02);

/// Volume of the last block from the mic. The debug panel shows it.
final micVolume = ValueNotifier<double>(0);

/// Receives all the audio of the current sentence. [isFinal] is false while
/// the person is still talking and true when the sentence is over.
typedef ChunkCallback = void Function(List<int> samples, bool isFinal);

// ---- Volume ----

/// RMS (root mean square) volume of a block, from 0 to 1.
///
/// Sound samples swing above and below zero, so a plain average would be
/// close to zero even for loud sound. Squaring makes every sample positive,
/// then we average and take the square root to get back to the same scale.
double rmsVolume(List<int> samples) {
  if (samples.isEmpty) return 0;

  var sumOfSquares = 0.0;
  for (final sample in samples) {
    // A 16-bit sample goes from -32768 to 32767. Scale it to -1..1.
    final value = sample / 32768;
    sumOfSquares += value * value;
  }
  return sqrt(sumOfSquares / samples.length);
}

/// The mic sends bytes. Every sample is 2 bytes (16 bits), low byte first.
List<int> bytesToSamples(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = <int>[];
  for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
    samples.add(data.getInt16(offset, Endian.little));
  }
  return samples;
}

// ---- Rolling buffer ----

/// All the audio of the sentence being spoken. Empty while nobody talks.
List<int> speechBuffer = [];

/// Silence in a row at the end of the buffer.
int silentSamples = 0;

/// Audio added to the buffer since the last partial was emitted.
int samplesSincePartial = 0;

void resetAudioBuffer() {
  speechBuffer = [];
  silentSamples = 0;
  samplesSincePartial = 0;
}

/// Feeds one block of mic audio into the rolling buffer.
void addSamples(List<int> block, ChunkCallback onChunk) {
  final volume = rmsVolume(block);
  final isSpeech = volume >= volumeThreshold.value;
  micVolume.value = volume;

  // Nobody is talking and nobody was: throw the block away.
  if (speechBuffer.isEmpty && !isSpeech) return;

  // Silent blocks are kept too once a sentence has started: the short pauses
  // between words are part of it.
  speechBuffer.addAll(block);
  samplesSincePartial += block.length;
  silentSamples = isSpeech ? 0 : silentSamples + block.length;

  final sentenceEnded = silentSamples >= silenceToFinishSamples;
  final tooLong = speechBuffer.length >= maxChunkSamples;
  if (sentenceEnded || tooLong) {
    finishChunk(onChunk);
    return;
  }

  // No partial during a pause: nothing new was said, and if the pause goes
  // on the final arrives in a moment anyway.
  if (isSpeech && samplesSincePartial >= partialEverySamples) {
    samplesSincePartial = 0;
    // A copy, because the buffer keeps growing after this.
    onChunk(List.of(speechBuffer), false);
  }
}

/// Emits the buffer as a final and starts over with an empty one.
void finishChunk(ChunkCallback onChunk) {
  if (speechBuffer.isEmpty) return;

  final chunk = speechBuffer;
  resetAudioBuffer();
  onChunk(chunk, true);
}

// ---- Microphone ----

final recorder = AudioRecorder();

/// The connection to the mic stream. Null while not listening.
StreamSubscription<Uint8List>? micSubscription;

/// Starts the mic. Returns false if the user did not give permission.
/// The audio only lives in memory; nothing is written to disk.
Future<bool> startListening(ChunkCallback onChunk) async {
  // The first time, this shows the Android permission dialog.
  if (!await recorder.hasPermission()) return false;

  const config = RecordConfig(
    encoder: AudioEncoder.pcm16bits, // Raw samples, not a compressed format.
    sampleRate: sampleRate,
    numChannels: 1,
  );
  final micStream = await recorder.startStream(config);
  micSubscription = micStream.listen((bytes) {
    addSamples(bytesToSamples(bytes), onChunk);
  });
  return true;
}

Future<void> stopListening(ChunkCallback onChunk) async {
  await micSubscription?.cancel();
  micSubscription = null;
  await recorder.stop();
  micVolume.value = 0;

  // Paused in the middle of a sentence: keep what was heard as a final.
  finishChunk(onChunk);
}
