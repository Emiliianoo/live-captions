import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'captions.dart';
import 'fake_captions.dart';

// ---- Design system: every color, size and duration the screen uses ----

const backgroundColor = Color(0xFF000000);
const originalColor = Color(0xFFFFFFFF);
const translationColor = Color(0xFF9CC7E8); // Soft blue.
const partialColor = Color(0xFF9A9A9A); // Gray: not confirmed yet.
const mutedColor = Color(0xFFB0B0B0); // Language tag and hints.
const disabledColor = Color(0xFF4D4D4D);
const accentColor = Color(0xFFFFC53D); // Amber: numbers and the main button.

const spaceSmall = 8.0;
const spaceMedium = 16.0;
const spaceLarge = 24.0;
const spaceXLarge = 32.0;

const defaultFontSize = 28.0;
const minFontSize = 20.0;
const maxFontSize = 48.0;
const fontSizeStep = 4.0;
const translationScale = 0.7; // Translation size compared to the original.
const tagFontSize = 14.0;
const tagWidth = 40.0; // Left column that holds the EN/ES tag.

const mainButtonSize = 72.0;
const sideButtonSize = 56.0;

const quickAnimation = Duration(milliseconds: 200);
const gentleAnimation = Duration(milliseconds: 400);

/// Opacity of each line counting from the newest one. Lines past the fifth
/// keep the last value, so old text is still readable when scrolling back.
const lineOpacities = [1.0, 0.9, 0.8, 0.7, 0.6];

/// Tabular figures give every digit the same width, so a number does not
/// wobble sideways while the partial line grows.
const tabularFigures = [FontFeature.tabularFigures()];

const digitStyle = TextStyle(color: accentColor, fontWeight: FontWeight.w700);

const tagStyle = TextStyle(
  color: mutedColor,
  fontSize: tagFontSize,
  fontWeight: FontWeight.w600,
  letterSpacing: 1,
);

/// How often we check for lines older than 3 minutes.
const cleanupInterval = Duration(seconds: 10);

// ---- Screen ----

class CaptionScreen extends StatefulWidget {
  const CaptionScreen({super.key});

  @override
  State<CaptionScreen> createState() => _CaptionScreenState();
}

class _CaptionScreenState extends State<CaptionScreen> {
  double fontSize = defaultFontSize;
  Timer? fakeTimer; // Null while paused.
  late Timer cleanupTimer;

  bool get isRunning => fakeTimer != null;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep the screen on while this screen is open.
    // Old lines are removed even while paused, so text never lingers.
    cleanupTimer = Timer.periodic(cleanupInterval, (_) => removeOldCaptions());
  }

  @override
  void dispose() {
    fakeTimer?.cancel();
    cleanupTimer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void toggleRunning() {
    setState(() {
      if (isRunning) {
        fakeTimer?.cancel();
        fakeTimer = null;
      } else {
        fakeTimer = startFakeCaptions();
      }
    });
  }

  void changeFontSize(double change) {
    final newSize = (fontSize + change).clamp(minFontSize, maxFontSize);
    setState(() => fontSize = newSize.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // Rebuilds only the list every time the captions change.
              child: ValueListenableBuilder<List<CaptionLine>>(
                valueListenable: captions,
                builder: (context, lines, _) {
                  return buildCaptionList(lines, fontSize);
                },
              ),
            ),
            buildControls(
              isRunning: isRunning,
              onToggle: toggleRunning,
              // A null callback disables the button at the size limits.
              onSmaller: fontSize > minFontSize
                  ? () => changeFontSize(-fontSizeStep)
                  : null,
              onLarger: fontSize < maxFontSize
                  ? () => changeFontSize(fontSizeStep)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Caption list ----

Widget buildCaptionList(List<CaptionLine> lines, double fontSize) {
  if (lines.isEmpty) return buildEmptyHint();

  final newestFirst = lines.reversed.toList();
  return ListView(
    // Reversed: the newest line sits at the bottom and the user scrolls up
    // to read older lines that are still in memory.
    reverse: true,
    padding: const EdgeInsets.fromLTRB(spaceMedium, spaceLarge, spaceLarge, 0),
    children: [
      for (var position = 0; position < newestFirst.length; position++)
        buildCaptionLine(
          newestFirst[position],
          fontSize,
          opacityForPosition(position),
        ),
    ],
  );
}

double opacityForPosition(int positionFromNewest) {
  if (positionFromNewest >= lineOpacities.length) return lineOpacities.last;
  return lineOpacities[positionFromNewest];
}

Widget buildEmptyHint() {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(spaceXLarge),
      child: Text(
        'Toca iniciar para ver los subtítulos',
        textAlign: TextAlign.center,
        style: TextStyle(color: mutedColor, fontSize: 20),
      ),
    ),
  );
}

Widget buildCaptionLine(CaptionLine line, double fontSize, double opacity) {
  final originalStyle = TextStyle(
    color: line.isFinal ? originalColor : partialColor,
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    height: 1.3,
    fontFeatures: tabularFigures,
  );
  final translationStyle = TextStyle(
    color: translationColor,
    fontSize: fontSize * translationScale,
    height: 1.3,
    fontFeatures: tabularFigures,
  );

  // The key tells Flutter which row belongs to which sentence. Without it the
  // animations below would not follow a line when a new one pushes it up.
  return AnimatedOpacity(
    key: ValueKey(line.time),
    opacity: opacity,
    duration: gentleAnimation,
    child: Padding(
      padding: const EdgeInsets.only(bottom: spaceXLarge),
      child: Row(
        // Baseline: the small tag sits on the same text line as the first
        // row of the large text, instead of floating at the top.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: tagWidth,
            child: Text(line.language.toUpperCase(), style: tagStyle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animates gray -> white when the partial becomes final, and
                // the size when the user presses the font buttons.
                AnimatedDefaultTextStyle(
                  style: originalStyle,
                  duration: quickAnimation,
                  child: Text.rich(
                    TextSpan(children: highlightDigits(line.text)),
                  ),
                ),
                if (line.translation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: spaceSmall),
                    child: AnimatedDefaultTextStyle(
                      style: translationStyle,
                      duration: quickAnimation,
                      child: Text.rich(
                        TextSpan(children: highlightDigits(line.translation)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A number with the separators inside it, so 4471-2203, 1,250.50, 03/15/1988
/// and 10:30 are each highlighted as one piece.
final numberPattern = RegExp(r'\d+([.,:/-]\d+)*');

/// Splits [text] into plain pieces and highlighted number pieces.
List<TextSpan> highlightDigits(String text) {
  final spans = <TextSpan>[];
  var plainStart = 0;
  for (final match in numberPattern.allMatches(text)) {
    spans.add(TextSpan(text: text.substring(plainStart, match.start)));
    spans.add(TextSpan(text: match.group(0), style: digitStyle));
    plainStart = match.end;
  }
  spans.add(TextSpan(text: text.substring(plainStart)));
  return spans;
}

// ---- Buttons ----

Widget buildControls({
  required bool isRunning,
  required VoidCallback onToggle,
  required VoidCallback? onSmaller,
  required VoidCallback? onLarger,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: spaceMedium),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildFontButton(
          icon: Icons.text_decrease_rounded,
          tooltip: 'Letra más chica',
          onPressed: onSmaller,
        ),
        const SizedBox(width: spaceXLarge),
        IconButton(
          onPressed: onToggle,
          tooltip: isRunning ? 'Pausar' : 'Iniciar',
          iconSize: 40,
          style: IconButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: backgroundColor,
            fixedSize: const Size.square(mainButtonSize),
          ),
          // Cross-fades between the play and pause icons. The key changes
          // with the state, which is what tells the switcher to animate.
          icon: AnimatedSwitcher(
            duration: quickAnimation,
            child: Icon(
              isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(isRunning),
            ),
          ),
        ),
        const SizedBox(width: spaceXLarge),
        buildFontButton(
          icon: Icons.text_increase_rounded,
          tooltip: 'Letra más grande',
          onPressed: onLarger,
        ),
      ],
    ),
  );
}

Widget buildFontButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback? onPressed,
}) {
  return IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    iconSize: 28,
    style: IconButton.styleFrom(
      foregroundColor: originalColor,
      disabledForegroundColor: disabledColor,
      fixedSize: const Size.square(sideButtonSize),
    ),
    icon: Icon(icon),
  );
}
