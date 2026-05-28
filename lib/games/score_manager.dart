import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_base.dart';

/// 게임 점수/난이도/세션 관리
class ScoreManager {
  static const String _historyKey = 'game_session_history';
  static const int _maxHistorySize = 50;

  final FlutterTts _tts = FlutterTts();

  // --- 난이도 적응 ---

  /// 성공률 기반 난이도 조절.
  /// 현재 레벨과 최근 성공률을 받아 다음 레벨 반환.
  int adaptDifficulty(int currentLevel, double successRate) {
    if (successRate > 0.80 && currentLevel < 5) {
      return currentLevel + 1;
    } else if (successRate < 0.40 && currentLevel > 1) {
      return currentLevel - 1;
    }
    return currentLevel;
  }

  // --- TTS 피드백 ---

  Future<void> speakFeedback(String langCode, {required bool success}) async {
    final ttsLang = langCode == 'ko' ? 'ko-KR' : 'en-US';
    await _tts.setLanguage(ttsLang);
    await _tts.setPitch(1.0);

    if (success) {
      await _tts.speak(langCode == 'ko' ? '잘했어요!' : 'Great job!');
    } else {
      await _tts.speak(langCode == 'ko' ? '다시 도전해보세요!' : 'Try again!');
    }
  }

  Future<void> speakCountdown(String langCode) async {
    final ttsLang = langCode == 'ko' ? 'ko-KR' : 'en-US';
    await _tts.setLanguage(ttsLang);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    for (int i = 3; i > 0; i--) {
      await _tts.speak('$i');
      await _tts.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _tts.speak(langCode == 'ko' ? '시작!' : 'Start!');
  }

  // --- 세션 저장/로드 ---

  Future<void> saveResult(GameResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    final List<dynamic> sessions =
        raw != null ? jsonDecode(raw) as List<dynamic> : [];

    sessions.insert(0, result.toJson());

    // 최대 크기 유지
    if (sessions.length > _maxHistorySize) {
      sessions.removeRange(_maxHistorySize, sessions.length);
    }

    await prefs.setString(_historyKey, jsonEncode(sessions));
  }

  Future<List<GameResult>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];

    final List<dynamic> sessions = jsonDecode(raw) as List<dynamic>;
    return sessions
        .map((e) => GameResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
