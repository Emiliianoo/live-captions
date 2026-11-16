import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_captions/audio.dart';

/// The mic sends small blocks. The tests use 20 ms blocks (320 samples).
const blockSamples = sampleRate ~/ 50;

/// Every chunk the rolling buffer emitted during a test.
final chunkLengths = <int>[];
final chunkIsFinal = <bool>[];

void rememberChunk(List<int> samples, bool isFinal) {
  chunkLengths.add(samples.length);
  chunkIsFinal.add(isFinal);
}

int samplesIn(double seconds) => (seconds * sampleRate).round();

List<int> silence(double seconds) => List.filled(samplesIn(seconds), 0);

/// A 440 Hz tone at half volume, far above the default threshold.
List<int> tone(double seconds) {
  return List.generate(samplesIn(seconds), (i) {
    final wave = sin(2 * pi * 440 * i / sampleRate);
    return (wave * 0.5 * 32767).round();
  });
}

/// Feeds the audio to the rolling buffer in small blocks, like the mic does.
void feed(List<int> audio) {
  for (var start = 0; start < audio.length; start += blockSamples) {
    final end = min(start + blockSamples, audio.length);
    addSamples(audio.sublist(start, end), rememberChunk);
  }
}

void main() {
  setUp(() {
    resetAudioBuffer();
    chunkLengths.clear();
    chunkIsFinal.clear();
  });

  test('volume of silence is 0 and a tone is well above the threshold', () {
    expect(rmsVolume(silence(1)), 0);
    // The RMS of a sine wave is its peak divided by the square root of 2.
    expect(rmsVolume(tone(1)), closeTo(0.5 / sqrt(2), 0.01));
  });

  test('bytes become 16-bit samples, low byte first', () {
    final bytes = Uint8List.fromList([0x01, 0x00, 0xFF, 0x7F, 0x00, 0x80]);

    expect(bytesToSamples(bytes), [1, 32767, -32768]);
  });

  test('silence alone emits nothing', () {
    feed(silence(5));

    expect(chunkLengths, isEmpty);
  });

  test('silence, tone, silence: partials every second, then one final', () {
    feed(silence(1));
    feed(tone(2.5));
    feed(silence(1));

    expect(chunkIsFinal, [false, false, true]);
    // The final has the 2.5 s tone plus the 0.6 s of silence that ended it.
    // The first second of silence was thrown away.
    expect(chunkLengths, [samplesIn(1), samplesIn(2), samplesIn(3.1)]);
  });

  test('a short pause between words does not cut the sentence', () {
    feed(tone(1.5));
    feed(silence(0.3)); // Shorter than the 0.6 s that ends a sentence.
    feed(tone(1.5));
    feed(silence(1));

    final finals = chunkIsFinal.where((isFinal) => isFinal).length;
    expect(finals, 1);
    expect(chunkLengths.last, samplesIn(1.5 + 0.3 + 1.5 + 0.6));
  });

  test('speech without pauses is cut at 12 seconds', () {
    feed(tone(13));

    // Partials at 1 s, 2 s ... 11 s, then the final at 12 s.
    final firstFinal = chunkIsFinal.indexOf(true);
    expect(firstFinal, 11);
    expect(chunkLengths[firstFinal], maxChunkSamples);
    // The last second of the tone already belongs to the next sentence.
    expect(speechBuffer.length, samplesIn(1));
  });

  test('a higher threshold ignores the same tone', () {
    volumeThreshold.value = 0.9;
    addTearDown(() => volumeThreshold.value = 0.02);

    feed(tone(3));

    expect(chunkLengths, isEmpty);
  });
}
