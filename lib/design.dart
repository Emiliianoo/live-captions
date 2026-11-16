import 'package:flutter/painting.dart';

// Design system: every color, size and duration the screens use.

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
/// wobble sideways while it changes.
const tabularFigures = [FontFeature.tabularFigures()];

const digitStyle = TextStyle(color: accentColor, fontWeight: FontWeight.w700);

const tagStyle = TextStyle(
  color: mutedColor,
  fontSize: tagFontSize,
  fontWeight: FontWeight.w600,
  letterSpacing: 1,
);

// Text of the debug panel.
const panelLabelStyle = TextStyle(color: originalColor, fontSize: 16);
const panelValueStyle = TextStyle(
  color: originalColor,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  fontFeatures: tabularFigures,
);
const panelHintStyle = TextStyle(color: mutedColor, fontSize: 14, height: 1.4);
