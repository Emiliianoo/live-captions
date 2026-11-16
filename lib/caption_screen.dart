import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio.dart';
import 'captions.dart';
import 'debug_panel.dart';
import 'design.dart';
import 'transcribe.dart';
import 'translate.dart';

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

  /// 'checking', 'downloading', 'ready' or 'failed'.
  String modelStatus = 'checking';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep the screen on while this screen is open.
    // Old lines are removed even while paused, so text never lingers.
    cleanupTimer = Timer.periodic(cleanupInterval, (_) => removeOldCaptions());
    prepareModels();
  }

  /// Gets the speech and translation models ready. The first time, this
  /// downloads them.
  Future<void> prepareModels() async {
    // Show the download message only when a download is really needed.
    final hasSpeech = await isWhisperModelDownloaded();
    final hasTranslation = await isTranslationModelDownloaded();
    if (!hasSpeech || !hasTranslation) {
      setState(() => modelStatus = 'downloading');
    }
    try {
      await downloadWhisperModel();
      await downloadTranslationModel();
      setState(() => modelStatus = 'ready');
    } catch (error) {
      debugPrint('Model download failed: $error'); // Usually: no internet.
      setState(() => modelStatus = 'failed');
    }
  }

  @override
  void dispose() {
    stopListening(transcribeChunk);
    cleanupTimer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> toggleRunning() async {
    // After a failed download, the button tries the download again.
    if (modelStatus == 'failed') {
      prepareModels();
      return;
    }
    if (modelStatus != 'ready') return;

    // Ignore a second tap while the first one is still being handled.
    if (isSwitching) return;
    isSwitching = true;
    try {
      if (isRunning) {
        await stopListening(transcribeChunk);
        setState(() => isRunning = false);
        return;
      }

      final started = await startListening(transcribeChunk);
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
                    return buildCaptionList(lines, fontSize, modelStatus);
                  },
                ),
              ),
            ),
            // Slides the panel open and closed instead of making it jump.
            AnimatedSize(
              duration: quickAnimation,
              curve: softCurve,
              child: showDebugPanel
                  ? buildDebugPanel()
                  : const SizedBox(width: double.infinity),
            ),
            buildControls(
              isRunning: isRunning,
              // Disabled while the model downloads.
              onToggle: modelStatus == 'downloading' ? null : toggleRunning,
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

void showMicPermissionMessage(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // Floating and rounded, like the rest of the screen.
      behavior: SnackBarBehavior.floating,
      backgroundColor: trackColor,
      elevation: 0, // No shadow: on a dark screen it only adds a black edge.
      // Sits just above the button bar instead of covering it.
      margin: const EdgeInsets.fromLTRB(
        spaceMedium,
        0,
        spaceMedium,
        spaceMedium + barHeight + spaceSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      content: const Text(
        'Sin permiso de micrófono. Actívalo en los ajustes del teléfono.',
        style: panelLabelStyle,
      ),
    ),
  );
}

// ---- Caption list ----

Widget buildCaptionList(
  List<CaptionLine> lines,
  double fontSize,
  String modelStatus,
) {
  if (lines.isEmpty) return buildEmptyHint(modelStatus);

  final newestFirst = lines.reversed.toList();
  return ListView(
    // Reversed: the newest line sits at the bottom and the user scrolls up
    // to read older lines that are still in memory.
    reverse: true,
    padding: const EdgeInsets.fromLTRB(
      spaceMedium,
      spaceMedium,
      spaceMedium,
      spaceCompact,
    ),
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

/// What the screen says while there are no captions.
Widget buildEmptyHint(String modelStatus) {
  var title = 'Listo para escuchar';
  var hint = 'Toca iniciar y acerca el teléfono a la bocina.';
  if (modelStatus == 'downloading') {
    title = 'Descargando los modelos';
    hint = 'Voz y traducción. Solo pasa la primera vez, conéctate a wifi.';
  }
  if (modelStatus == 'failed') {
    title = 'No se pudieron descargar los modelos';
    hint = 'Revisa tu conexión y toca iniciar para reintentar.';
  }

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(spaceXLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mainButtonSize,
            height: mainButtonSize,
            decoration: const BoxDecoration(
              color: surfaceColor,
              shape: BoxShape.circle,
            ),
            // A spinner while downloading, the mic icon the rest of the time.
            child: modelStatus == 'downloading'
                ? const Padding(
                    padding: EdgeInsets.all(spaceLarge),
                    child: CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(
                    Icons.mic_none_rounded,
                    color: mutedColor,
                    size: 32,
                  ),
          ),
          const SizedBox(height: spaceLarge),
          Text(title, textAlign: TextAlign.center, style: emptyTitleStyle),
          const SizedBox(height: spaceSmall),
          Text(hint, textAlign: TextAlign.center, style: emptyHintStyle),
        ],
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
    letterSpacing: -0.2, // Large text reads better slightly tighter.
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
    curve: softCurve,
    // Each caption sits on its own rounded card.
    child: Container(
      margin: const EdgeInsets.only(bottom: spaceCompact),
      padding: const EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Row(
        // Baseline: the small tag sits on the same text line as the first
        // row of the large text, instead of floating at the top.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // No tag while the language is unknown.
          if (line.language.isNotEmpty)
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
                  curve: softCurve,
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
                      curve: softCurve,
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

/// The three buttons, inside a floating bar with fully round ends.
Widget buildControls({
  required bool isRunning,
  required VoidCallback? onToggle,
  required VoidCallback? onSmaller,
  required VoidCallback? onLarger,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: spaceSmall, bottom: spaceMedium),
    child: Center(
      child: Container(
        padding: const EdgeInsets.all(barPadding),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(barRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Only as wide as the buttons.
          children: [
            const SizedBox(width: barEndInset),
            buildFontButton(
              icon: Icons.text_decrease_rounded,
              tooltip: 'Letra más chica',
              onPressed: onSmaller,
            ),
            const SizedBox(width: spaceMedium),
            buildMainButton(isRunning, onToggle),
            const SizedBox(width: spaceMedium),
            buildFontButton(
              icon: Icons.text_increase_rounded,
              tooltip: 'Letra más grande',
              onPressed: onLarger,
            ),
            const SizedBox(width: barEndInset),
          ],
        ),
      ),
    ),
  );
}

Widget buildMainButton(bool isRunning, VoidCallback? onToggle) {
  return IconButton(
    onPressed: onToggle,
    tooltip: isRunning ? 'Pausar' : 'Iniciar',
    iconSize: 36,
    style: IconButton.styleFrom(
      backgroundColor: accentColor,
      foregroundColor: backgroundColor,
      disabledBackgroundColor: trackColor,
      disabledForegroundColor: disabledColor,
      fixedSize: const Size.square(mainButtonSize),
    ),
    // Cross-fades between the play and pause icons. The key changes with the
    // state, which is what tells the switcher to animate.
    icon: AnimatedSwitcher(
      duration: quickAnimation,
      switchInCurve: softCurve,
      child: Icon(
        isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey(isRunning),
      ),
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
    iconSize: 26,
    style: IconButton.styleFrom(
      foregroundColor: originalColor,
      disabledForegroundColor: disabledColor,
      fixedSize: const Size.square(sideButtonSize),
    ),
    icon: Icon(icon),
  );
}
