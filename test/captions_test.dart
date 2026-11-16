import 'package:flutter_test/flutter_test.dart';
import 'package:live_captions/captions.dart';

/// A fixed "now" so the test does not depend on the real clock.
final now = DateTime(2026, 1, 1, 12, 0, 0);

/// Builds a line that started [age] before [now].
CaptionLine lineWithAge(Duration age, {bool isFinal = true}) {
  return CaptionLine(
    text: 'Hello',
    translation: isFinal ? 'Hola' : '',
    language: 'en',
    time: now.subtract(age),
    isFinal: isFinal,
  );
}

void main() {
  test('keeps a final line that is 2:59 old', () {
    final line = lineWithAge(const Duration(minutes: 2, seconds: 59));

    expect(removeOldLines([line], now), [line]);
  });

  test('removes a final line that is 3:01 old', () {
    final line = lineWithAge(const Duration(minutes: 3, seconds: 1));

    expect(removeOldLines([line], now), isEmpty);
  });

  test('removes only the old lines and keeps the order', () {
    final oldLine = lineWithAge(const Duration(minutes: 5));
    final recentLine = lineWithAge(const Duration(minutes: 1));
    final newestLine = lineWithAge(const Duration(seconds: 10));

    final result = removeOldLines([oldLine, recentLine, newestLine], now);

    expect(result, [recentLine, newestLine]);
  });

  test('never removes the partial line, even if it is old', () {
    final partial = lineWithAge(const Duration(minutes: 4), isFinal: false);

    expect(removeOldLines([partial], now), [partial]);
  });

  test('clearing removes every line, including the partial', () {
    showFinal('Hello', 'Hola', 'en');
    showPartial('How are', 'en');

    clearCaptions();

    expect(captions.value, isEmpty);
  });
}
