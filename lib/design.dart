import 'package:flutter/widgets.dart';

// Design system: every color, size and duration the screens use.

// ---- Colors ----
// No pure black and no pure white: dark grays with a hint of blue and an
// off-white are easier on the eyes during a long shift.

const backgroundColor = Color(0xFF111216);
const surfaceColor = Color(0xFF1B1D22); // Caption cards, panel, button bar.
const trackColor = Color(0xFF2A2D34); // Empty part of the slider and the bar.
const originalColor = Color(0xFFECEEF2); // Off-white.
const translationColor = Color(0xFFA3BFDB); // Soft blue.
const partialColor = Color(0xFF8B8F99); // Gray: not confirmed yet.
const mutedColor = Color(0xFF9BA0AB); // Language tag and hints.
const disabledColor = Color(0xFF4A4E57);
const accentColor = Color(0xFFF2C66D); // Soft gold: numbers and main button.

// ---- Spacing ----

const spaceSmall = 8.0;
const spaceCompact = 12.0;
const spaceMedium = 16.0;
const spaceLarge = 24.0;
const spaceXLarge = 32.0;

// ---- Corners ----

const cardRadius = 24.0;
const cardPadding = 16.0;

/// A rounded shape inside a card uses the card's radius minus the padding
/// between them. That keeps the two curves parallel.
const innerRadius = cardRadius - cardPadding;

// ---- Text ----

const defaultFontSize = 28.0;
const minFontSize = 20.0;
const maxFontSize = 48.0;
const fontSizeStep = 4.0;
const translationScale = 0.7; // Translation size compared to the original.
const tagFontSize = 14.0;
const tagWidth = 36.0; // Left column that holds the EN/ES tag.

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

const emptyTitleStyle = TextStyle(
  color: originalColor,
  fontSize: 22,
  fontWeight: FontWeight.w600,
);
const emptyHintStyle = TextStyle(color: mutedColor, fontSize: 16, height: 1.4);

// Text of the debug panel.
const panelLabelStyle = TextStyle(color: originalColor, fontSize: 16);
const panelValueStyle = TextStyle(
  color: originalColor,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  fontFeatures: tabularFigures,
);
const panelHintStyle = TextStyle(color: mutedColor, fontSize: 14, height: 1.4);

// ---- Button bar ----

const mainButtonSize = 72.0;
const sideButtonSize = 52.0;
const barPadding = 8.0;
const barHeight = mainButtonSize + barPadding * 2;

/// Same corner rule as the cards, the other way around: the bar wraps a round
/// button, so its radius is the button's radius plus the padding.
const barRadius = mainButtonSize / 2 + barPadding;

/// Extra room at both ends of the bar, so a small button is as far from the
/// bar's round end as it is from its top and bottom.
const barEndInset = (mainButtonSize - sideButtonSize) / 2;

// ---- Motion ----

const quickAnimation = Duration(milliseconds: 220);
const gentleAnimation = Duration(milliseconds: 450);

/// Starts fast and settles slowly, so nothing stops with a jolt.
const softCurve = Curves.easeOutCubic;

/// Opacity of each line counting from the newest one. Lines past the fifth
/// keep the last value, so old text is still readable when scrolling back.
const lineOpacities = [1.0, 0.9, 0.8, 0.7, 0.6];
