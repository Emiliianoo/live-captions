import 'package:flutter/foundation.dart';

/// One caption line: the original text and, once it is final, its translation.
class CaptionLine {
  const CaptionLine({
    required this.text,
    required this.translation,
    required this.language,
    required this.time,
    required this.isFinal,
  });

  final String text;
  final String translation; // Empty while the line is still a partial.
  final String language; // 'en' or 'es'.
  final DateTime time; // When the sentence started.
  final bool isFinal;
}

/// Final lines older than this are removed from memory.
const maxLineAge = Duration(minutes: 3);

/// Every line currently in memory, oldest first. Nothing is written to disk.
/// The last line can be a partial (a sentence that is still being spoken).
final captions = ValueNotifier<List<CaptionLine>>([]);

/// Shows the sentence being spoken right now, replacing the previous partial.
void showPartial(String text, String language) {
  replaceLastLine(text, '', language, false);
}

/// Turns the current partial into a final line with its translation.
void showFinal(String text, String translation, String language) {
  replaceLastLine(text, translation, language, true);
}

void replaceLastLine(
  String text,
  String translation,
  String language,
  bool isFinal,
) {
  final lines = captions.value;
  final hasPartial = lines.isNotEmpty && !lines.last.isFinal;

  // Keep the time of the partial we are replacing. The screen uses the time
  // to recognize the line, so the same sentence stays the same row while it
  // grows and when it becomes final.
  final time = hasPartial ? lines.last.time : DateTime.now();

  final finalLines = lines.where((line) => line.isFinal);
  final newLine = CaptionLine(
    text: text,
    translation: translation,
    language: language,
    time: time,
    isFinal: isFinal,
  );
  captions.value = [...finalLines, newLine];
}

/// Returns the lines without the final ones older than [maxLineAge].
/// [now] is a parameter so a test can pretend that time has passed.
List<CaptionLine> removeOldLines(List<CaptionLine> lines, DateTime now) {
  return lines.where((line) {
    if (!line.isFinal) return true; // The partial is still being spoken.
    return now.difference(line.time) <= maxLineAge;
  }).toList();
}

/// Removes the old lines from the list the screen is showing.
void removeOldCaptions() {
  captions.value = removeOldLines(captions.value, DateTime.now());
}
