import 'dart:async';

import 'captions.dart';

// Fake data for Phase 1. Delete this file when the real microphone arrives.

/// Scripted call: each sentence has its language, text and translation.
const fakeSentences = [
  (
    language: 'en',
    text: 'Hi, I am calling about my policy number 4471-2203.',
    translation: 'Hola, llamo por mi póliza número 4471-2203.',
  ),
  (
    language: 'es',
    text: 'Claro, ¿me confirma su fecha de nacimiento?',
    translation: 'Sure, can you confirm your date of birth?',
  ),
  (language: 'en', text: 'It is 03/15/1988.', translation: 'Es el 15/03/1988.'),
  (
    language: 'es',
    text: 'Gracias. Su pago mensual es de 1,250.50 pesos.',
    translation: 'Thank you. Your monthly payment is 1,250.50 pesos.',
  ),
  (
    language: 'en',
    text: 'I thought it was 980 until December.',
    translation: 'Pensé que era de 980 hasta diciembre.',
  ),
  (
    language: 'es',
    text: 'Subió el 1 de octubre. Su próximo cargo es el día 28.',
    translation: 'It went up on October 1. Your next charge is on the 28th.',
  ),
  (
    language: 'en',
    text: 'Okay, can you send the receipt to my phone? It ends in 0147.',
    translation: '¿Puede enviar el recibo a mi teléfono? Termina en 0147.',
  ),
  (
    language: 'es',
    text: 'Listo, lo recibirá en unos 5 minutos.',
    translation: 'Done, you will receive it in about 5 minutes.',
  ),
];

/// How often the fake speaker says one more word.
const fakeWordInterval = Duration(milliseconds: 250);

/// Timer ticks of silence between two sentences.
const fakeSilenceTicks = 3;

int fakeSentenceIndex = 0;

/// Words of the current sentence shown so far. It starts each sentence below
/// zero so the first few ticks are silence.
int fakeWordCount = 0;

/// Starts the fake speaker. Cancel the returned timer to pause it.
Timer startFakeCaptions() {
  return Timer.periodic(fakeWordInterval, (_) => showNextFakeWord());
}

/// One tick: show one more word, or finish the sentence once all are shown.
void showNextFakeWord() {
  final sentence = fakeSentences[fakeSentenceIndex];
  final words = sentence.text.split(' ');

  fakeWordCount++;
  if (fakeWordCount <= 0) return; // Still in the silence between sentences.

  if (fakeWordCount <= words.length) {
    final spokenSoFar = words.take(fakeWordCount).join(' ');
    showPartial(spokenSoFar, sentence.language);
    return;
  }

  showFinal(sentence.text, sentence.translation, sentence.language);
  fakeSentenceIndex = (fakeSentenceIndex + 1) % fakeSentences.length;
  fakeWordCount = -fakeSilenceTicks;
}
