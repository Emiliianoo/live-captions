import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'audio.dart';
import 'captions.dart';

// For now the app only listens to English.

/// The ".en" models only know English, which makes them better at it.
/// `tinyEn` is the fastest. `baseEn` is more accurate but about 3 times
/// slower. Change it here to compare.
const whisperModel = WhisperModel.tinyEn;

/// A final chunk ends with 0.6 s of silence. If the whole chunk is shorter
/// than this, less than 0.3 s of it was sound: a click or a knock, not a
/// word. Whisper is slow, so those are not worth its time.
const shortestSpeechSamples = sampleRate * 9 ~/ 10;

final whisper = WhisperController();

/// Where the model file is on the phone. Set by [downloadWhisperModel].
String whisperModelPath = '';

// ---- Model ----

Future<bool> isWhisperModelDownloaded() async {
  final path = await whisper.getPath(whisperModel);
  return File(path).existsSync();
}

/// Downloads the model the first time. After that it only finds the file.
/// This is the only time the app uses the internet.
Future<void> downloadWhisperModel() async {
  whisperModelPath = await whisper.downloadModel(whisperModel);
}

// ---- One chunk of audio -> text ----

/// Turns English audio into text.
Future<String> transcribe(List<int> samples) async {
  // The package's usual transcribe() only reads audio files, and this app
  // never writes audio to disk. A "live session" takes audio from memory
  // instead, so we open one, give it the whole chunk and close it.
  final session = await startWhisperLiveSession(
    modelPath: whisperModelPath,
    lang: 'en',
    // Loading the model takes seconds. This keeps it in memory after the
    // first time.
    keepModelLoaded: true,
    // The session has its own silence filter. audio.dart already decided
    // that this chunk is speech, so these two zeros turn that filter off.
    gateRmsMin: 0,
    gateVoiceRatio: 0,
  );
  final stopwatch = Stopwatch();
  stopwatch.start();
  session.feed(samplesToBytes(samples));
  final text = await session.stop();

  // Shows in the `flutter run` console how long Whisper took.
  final audioSeconds = (samples.length / sampleRate).toStringAsFixed(1);
  final tookMs = stopwatch.elapsedMilliseconds;
  debugPrint('Whisper: $audioSeconds s of audio in $tookMs ms');

  return cleanText(text);
}

/// The session wants the audio the way the mic sends it: 2 bytes per sample.
Uint8List samplesToBytes(List<int> samples) {
  return Int16List.fromList(samples).buffer.asUint8List();
}

/// Whisper writes things like "[BLANK_AUDIO]" or "(music)" for sounds that
/// are not speech. Those are not captions, so they become empty text.
String cleanText(String text) {
  final trimmed = text.trim();
  if (trimmed.startsWith('[') || trimmed.startsWith('(')) return '';
  return trimmed;
}

// ---- Chunks from the mic ----

/// Chunks that are being transcribed or waiting for their turn.
int chunksWaiting = 0;

/// Finishes when Whisper is free. Each new chunk is chained after it, so
/// chunks are transcribed one at a time and in order.
Future<void> whisperTurn = Future.value();

/// Receives every partial and final chunk from audio.dart.
void transcribeChunk(List<int> samples, bool isFinal) {
  // Whisper can only do one job at a time. A partial that arrives while it
  // is busy is skipped, because a newer one comes in about a second. A final
  // is never skipped: it waits for its turn.
  if (!isFinal && chunksWaiting > 0) return;

  // Too short to be a word.
  if (isFinal && samples.length < shortestSpeechSamples) return;

  chunksWaiting++;
  whisperTurn = whisperTurn.then((_) => transcribeAndShow(samples, isFinal));
}

Future<void> transcribeAndShow(List<int> samples, bool isFinal) async {
  // try / finally: even if Whisper fails, the chunk must stop counting as
  // waiting. Otherwise every later partial would be skipped forever.
  try {
    final text = await transcribe(samples);

    if (text.isEmpty) {
      // It was only noise. Take away the gray line if there was one.
      if (isFinal) removePartial();
    } else if (isFinal) {
      showFinal(text, '', 'en'); // The translation comes later.
    } else {
      showPartial(text, 'en');
    }
  } catch (error) {
    debugPrint('Whisper failed: $error');
  } finally {
    chunksWaiting--;
  }
}
