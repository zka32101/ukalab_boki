import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/foundation.dart';

/// ながら学習モードの設定（アプリ全体で共有）。[appThemeMode] と同じく、画面側は
/// この値を購読するだけでよい（Riverpod の ProviderScope は要らない）。
final ValueNotifier<HandsFreeSettings> appHandsFree = ValueNotifier(const HandsFreeSettings());

final HandsFreeStore _store = SharedPreferencesHandsFreeStore('boki3');

/// 読み上げの実体。既定は端末標準の音声合成。テストでは [FakeSpeechBackend] に差し替える。
SpeechBackend? _backendOverride;
SpeechBackend? _defaultBackend;

@visibleForTesting
set appSpeechBackendForTest(SpeechBackend? backend) => _backendOverride = backend;

class _CurrentBackend implements AwaitableSpeechBackend {
  SpeechBackend get _current =>
      _backendOverride ?? (_defaultBackend ??= FlutterTtsSpeechBackend());

  @override
  Future<void> speak(String text, {double rate = 1.0}) => _current.speak(text, rate: rate);

  /// ながらセッションが読み終わりを待つ入口。実体が待てない型なら、目安の時間だけ待つ。
  @override
  Future<void> speakAndWait(String text, {double rate = 1.0}) {
    final current = _current;
    if (current is AwaitableSpeechBackend) return current.speakAndWait(text, rate: rate);
    return current
        .speak(text, rate: rate)
        .then((_) => Future<void>.delayed(NagaraSessionController.estimateSpeechDuration(text, rate)));
  }

  @override
  Future<void> stop() => _current.stop();
}

/// ながらセッション（kit の `NagaraSessionView`）に渡す、アプリ共通の読み上げの実体。
final SpeechBackend appSpeechBackend = _CurrentBackend();

/// 設定（[appHandsFree]）に従って、問題・解説を読み上げる。
final HandsFreeSpeaker appSpeaker = HandsFreeSpeaker(
  backend: _CurrentBackend(),
  settings: () => appHandsFree.value,
);

/// 起動時に保存済みの設定を読み込む。
Future<void> loadHandsFree() async {
  appHandsFree.value = HandsFreeSettings.fromJson(await _store.read());
}

/// 設定を変更し、端末内に保存する。
Future<void> updateHandsFree(HandsFreeSettings settings) async {
  appHandsFree.value = settings;
  await _store.write(settings.toJson());
}
