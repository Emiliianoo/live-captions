import 'package:flutter_test/flutter_test.dart';
import 'package:live_captions/audio.dart';
import 'package:live_captions/transcribe.dart';

void main() {
  test('sound descriptions from Whisper become empty text', () {
    expect(cleanText(' [BLANK_AUDIO] '), '');
    expect(cleanText('(music)'), '');
    expect(cleanText('  Hello there. '), 'Hello there.');
  });

  test('samples turn back into the same bytes the mic sent', () {
    final samples = [1, 32767, -32768, 0];

    expect(bytesToSamples(samplesToBytes(samples)), samples);
  });
}
