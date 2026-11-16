import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

// For now the app only translates English into Spanish.

/// Created once and reused for every sentence.
final translator = OnDeviceTranslator(
  sourceLanguage: TranslateLanguage.english,
  targetLanguage: TranslateLanguage.spanish,
);

final translationModels = OnDeviceTranslatorModelManager();

Future<bool> isTranslationModelDownloaded() {
  return translationModels.isModelDownloaded(TranslateLanguage.spanish.bcpCode);
}

/// Gets the translator ready by translating one word. The first time, that
/// makes ML Kit download its language model. It also loads the model into
/// memory, so the first real sentence is not slow.
Future<void> downloadTranslationModel() async {
  await translator.translateText('hello');
}

/// Returns the Spanish text, or empty text if the translation fails. That
/// way the original line still shows up without it.
Future<String> translateToSpanish(String text) async {
  try {
    return await translator.translateText(text);
  } catch (error) {
    debugPrint('Translation failed: $error');
    return '';
  }
}
