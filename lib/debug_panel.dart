import 'package:flutter/material.dart';

import 'audio.dart';
import 'design.dart';

/// Right end of the slider and of the volume bar. With the phone next to the
/// speaker, the threshold should never need to be higher than this.
const maxVolumeThreshold = 0.1;

/// Hidden panel to tune the volume threshold. A long press on the captions
/// shows or hides it.
Widget buildDebugPanel() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(spaceLarge, spaceMedium, spaceLarge, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: volumeThreshold,
          builder: (context, threshold, _) => buildThresholdSlider(threshold),
        ),
        const SizedBox(height: spaceMedium),
        ValueListenableBuilder<double>(
          valueListenable: micVolume,
          builder: (context, volume, _) => buildVolumeMeter(volume),
        ),
        const SizedBox(height: spaceMedium),
        const Text(
          'La barra se pinta de amarillo cuando el volumen pasa el umbral '
          'y cuenta como voz.',
          style: panelHintStyle,
        ),
      ],
    ),
  );
}

Widget buildThresholdSlider(double threshold) {
  return Column(
    children: [
      buildLabelAndValue('Umbral de voz', threshold),
      Slider(
        value: threshold,
        max: maxVolumeThreshold,
        activeColor: accentColor,
        // The slider draws its own side margin; removing it lines the track
        // up with the labels and the volume bar.
        padding: const EdgeInsets.symmetric(vertical: spaceMedium),
        onChanged: (newThreshold) => volumeThreshold.value = newThreshold,
      ),
    ],
  );
}

Widget buildVolumeMeter(double volume) {
  final isSpeech = volume >= volumeThreshold.value;
  return Column(
    children: [
      buildLabelAndValue('Volumen del micrófono', volume),
      const SizedBox(height: spaceSmall),
      LinearProgressIndicator(
        // Same scale as the slider. Louder sound just fills the whole bar.
        value: (volume / maxVolumeThreshold).clamp(0, 1).toDouble(),
        minHeight: spaceSmall,
        borderRadius: BorderRadius.circular(spaceSmall / 2),
        color: isSpeech ? accentColor : mutedColor,
        backgroundColor: disabledColor,
      ),
    ],
  );
}

Widget buildLabelAndValue(String label, double value) {
  return Row(
    children: [
      Expanded(child: Text(label, style: panelLabelStyle)),
      Text(value.toStringAsFixed(3), style: panelValueStyle),
    ],
  );
}
