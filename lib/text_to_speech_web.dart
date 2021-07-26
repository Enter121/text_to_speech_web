import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:js';
import 'package:text_to_speech_platform_interface/text_to_speech_platform.dart';

enum TtsStatus { playing, stopped, paused, resumed, error }

/// A web implementation of the TextToSpeech plugin.
class TextToSpeech extends TextToSpeechPlatform {
  TextToSpeech() {
    _init();
  }

  TtsStatus status = TtsStatus.stopped;
  html.SpeechSynthesisUtterance? utterance;
  html.SpeechSynthesis? synth;
  List<String> languages = <String>[];

  /// Registers this class as the default instance of [UrlLauncherPlatform].
  static void registerWith(Registrar registrar) {
    TextToSpeechPlatform.instance = TextToSpeech();
  }

  void _init() {
    utterance = html.SpeechSynthesisUtterance();
    synth = html.window.speechSynthesis;
    _listenState();
  }

  void _listenState() {
    if (utterance == null) {
      throw PlatformException(
        code: 'Uninitialised',
        details: 'SpeechSynthesisUtterance is not ready',
      );
    }

    utterance!.onStart.listen((event) {
      status = TtsStatus.playing;
    });
    utterance!.onEnd.listen((event) {
      status = TtsStatus.stopped;
    });
    utterance!.onPause.listen((event) {
      status = TtsStatus.paused;
    });
    utterance!.onResume.listen((event) {
      status = TtsStatus.resumed;
    });
    utterance!.onError.listen((event) {
      status = TtsStatus.error;

      /// re-initialise instance when error occurred
      _init();
    });
  }

  @override
  Future<bool?> speak(String text) {
    if (status != TtsStatus.stopped && status != TtsStatus.playing) {
      return Future<bool>.value(false);
    }

    try {
      stop();
      utterance!.text = text;
      synth!.speak(utterance!);
      return Future<bool>.value(true);
    } catch (e) {
      print('speak() error: ${e.toString()}');
      return Future<bool>.value(false);
    }
  }

  @override
  Future<bool?> stop() {
    if (status != TtsStatus.playing) {
      return Future<bool>.value(false);
    }

    try {
      synth!.cancel();
      return Future<bool>.value(true);
    } catch (e) {
      print('stop() error: ${e.toString()}');
      return Future<bool>.value(false);
    }
  }

  @override
  Future<bool?> pause() {
    try {
      synth!.pause();
      return Future<bool>.value(true);
    } catch (e) {
      print('pause() error: ${e.toString()}');
      return Future<bool>.value(false);
    }
  }

  @override
  Future<bool?> resume() {
    try {
      synth!.resume();
      return Future<bool>.value(true);
    } catch (e) {
      print('resume() error: ${e.toString()}');
      return Future<bool>.value(false);
    }
  }

  @override
  Future<bool?> setRate(num rate) {
    try {
      if (utterance != null) {
        utterance!.rate = rate;
        return Future<bool>.value(true);
      }
    } catch (e) {
      print('setRate() error: ${e.toString()}');
    }
    return Future<bool>.value(false);
  }

  @override
  Future<bool?> setVolume(num volume) {
    try {
      if (utterance != null) {
        utterance!.volume = volume;
        return Future<bool>.value(true);
      }
    } catch (e) {
      print('setVolume() error: ${e.toString()}');
    }
    return Future<bool>.value(false);
  }

  @override
  Future<bool?> setPitch(num pitch) {
    try {
      if (utterance != null) {
        utterance!.pitch = pitch;
        return Future<bool>.value(true);
      }
    } catch (e) {
      print('setPitch() error: ${e.toString()}');
    }
    return Future<bool>.value(false);
  }

  @override
  Future<bool?> setLanguage(String language) {
    try {
      if (utterance != null) {
        utterance!.lang = language;
        return Future<bool>.value(true);
      }
    } catch (e) {
      print('setPitch() error: ${e.toString()}');
    }
    return Future<bool>.value(false);
  }

  @override
  Future<String?> getDefaultLanguage() {
    return Future.value('en-US');
  }

  /// Return list of supported language code (i.e en-US)
  /// SpeechSynthesis Web API doesn't provide specific function to get supported language
  /// We get it from getVoice function instead
  @override
  Future<List<String>> getLanguages() {
    List<String> voices = _getVoicesLang();

    /// Prevent convert to Set first to avoid duplication and convert back to list
    return Future.value(voices.toSet().toList());
  }

  /// Return language of supported voice
  List<String> _getVoicesLang() {
    JsArray<dynamic>? voiceArray = _getVoices();
    List<String> voices = <String>[];
    if (voiceArray != null) {
      for (dynamic voice in voiceArray) {
        if (voice != null) {
          voices.add(voice['lang']);
        }
      }
    }
    return voices;
  }

  /// Returns native JS voice array
  JsArray<dynamic>? _getVoices() {
    return context['speechSynthesis'].callMethod('getVoices')
        as JsArray<dynamic>?;
  }

  @override
  Future<List<String>?> getVoice() {
    List<String> voices = <String>[];
    JsArray<dynamic>? voiceArray = _getVoices();
    if (voiceArray != null) {
      for (dynamic voice in voiceArray) {
        if (voice != null) {
          voices.add(voice['name']);
        }
      }
    }
    return Future.value(voices);
  }

  @override
  Future<List<String>?> getVoiceByLang(String lang) {
    List<String> voices = <String>[];
    JsArray<dynamic>? voiceArray = _getVoices();
    if (voiceArray != null) {
      for (dynamic voice in voiceArray) {
        if (voice != null) {
          if (voice['lang'] == lang) {
            voices.add(voice['name'] as String);
          }
        }
      }
    }
    return Future.value(voices);
  }
}
