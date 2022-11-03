import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:js';
import 'package:text_to_speech_platform_interface/text_to_speech_platform.dart';

enum TtsStatus { playing, stopped, paused, resumed, error }

/// A web implementation of the TextToSpeech plugin.
///
/// Web API reference:
/// - https://dvcs.w3.org/hg/speech-api/raw-file/tip/speechapi.html#tts-section
/// - https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis
class TextToSpeechWeb extends TextToSpeechPlatform {
  TextToSpeechWeb() {
    _init();
  }

  TtsStatus status = TtsStatus.stopped;
  html.SpeechSynthesisUtterance? utterance;
  html.SpeechSynthesis? synth;
  List<String> languages = <String>[];

  /// Registers this class as the default instance of [TextToSpeechPlatform].
  static void registerWith(Registrar registrar) {
    TextToSpeechPlatform.instance = TextToSpeechWeb();
  }

  /// Initialise speech synthesis API
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

  /// Stop current utterance (if playing) and start speak new utterance
  @override
  Future<bool?> speak(String text) {
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

  /// Stop current utterance immediately
  @override
  Future<bool?> stop() {
    try {
      synth!.cancel();
      return Future<bool>.value(true);
    } catch (e) {
      print('stop() error: ${e.toString()}');
      return Future<bool>.value(false);
    }
  }

  /// Pause current utterance immediately
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

  /// Resume current paused utterance
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

  /// Set rate (tempo) of next utterance
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

  /// Set volume of next utterance
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

  /// Set pitch of next utterance
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

  /// Set language of next utterance
  @override
  Future<bool?> setLanguage(String language) {
    try {
      if (utterance != null) {
        utterance!.lang = language;
        JsArray<dynamic> voiceArray = _getVoices();
        if (voiceArray != null) {
          for (dynamic voice in voiceArray) {
            if (voice != null) {
              if(voice['lang'].toString().contains(language)){
                utterance!.voice = voice['lang'];
              }
            }
          }
        }
        return Future<bool>.value(true);
      }
    } catch (e) {
      print('setPitch() error: ${e.toString()}');
    }
    return Future<bool>.value(false);
  }

  /// Get default language.
  /// Always returns 'English (en-US)'.
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

  /// Get list of supported voices
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

  /// Get language code of supported voices (e.g. en-US)
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
