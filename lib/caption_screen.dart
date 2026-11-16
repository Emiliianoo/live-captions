import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio.dart';
import 'captions.dart';
import 'debug_panel.dart';
import 'design.dart';

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
  bool isRunning = false;
  bool isSwitching = false; // True while the mic is starting or stopping.
  bool showDebugPanel = false;
  late Timer cleanupTimer;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep the screen on while this screen is open.
    // Old lines are removed even while paused, so text never lingers.
    cleanupTimer = Timer.periodic(cleanupInterval, (_) => removeOldCaptions());
  }

  @override
  void dispose() {
    stopListening(showChunk);
    cleanupTimer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> toggleRunning() async {
    // Ignore a second tap while the first one is still being handled.
    if (isSwitching) return;
    isSwitching = true;
    try {
      if (isRunning) {
        await stopListening(showChunk);
        setState(() => isRunning = false);
        return;
      }

      final started = await startListening(showChunk);
      if (!mounted) return; // The screen was closed while we waited.
      if (!started) {
        showMicPermissionMessage(context);
        return;
      }
      setState(() => isRunning = true);
    } finally {
      isSwitching = false;
    }
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
              // A long press on the captions shows or hides the debug panel.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // Empty areas count too.
                onLongPress: () {
                  setState(() => showDebugPanel = !showDebugPanel);
                },
                // Rebuilds only the list every time the captions change.
                child: ValueListenableBuilder<List<CaptionLine>>(
                  valueListenable: captions,
                  builder: (context, lines, _) {
                    return buildCaptionList(lines, fontSize);
                  },
                ),
              ),
            ),
            // Slides the panel open and closed instead of making it jump.
            AnimatedSize(
              duration: quickAnimation,
              child: showDebugPanel
                  ? buildDebugPanel()
                  : const SizedBox(width: double.infinity),
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

/// Placeholder until there is transcription: shows the kind and length of
/// each audio chunk ("parcial 1.8 s", "final 3.2 s"). The empty strings are
/// where the translation and the language will go.
void showChunk(List<int> samples, bool isFinal) {
  final seconds = (samples.length / sampleRate).toStringAsFixed(1);
  if (isFinal) {
    showFinal('final $seconds s', '', '');
  } else {
    showPartial('parcial $seconds s', '');
  }
}

void showMicPermissionMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Sin permiso de micrófono. Actívalo en los ajustes del teléfono.',
      ),
    ),
  );
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
