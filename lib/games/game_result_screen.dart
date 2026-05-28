import 'package:flutter/material.dart';
import '../generated/l10n.dart';
import 'game_base.dart';
import 'score_manager.dart';

class GameResultScreen extends StatelessWidget {
  final GameResult result;

  const GameResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // 결과 저장
    ScoreManager().saveResult(result);

    return Scaffold(
      appBar: AppBar(title: Text(loc.sessionResult)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result.accuracy >= 0.7 ? Icons.emoji_events : Icons.sentiment_satisfied,
              size: 80,
              color: result.accuracy >= 0.7 ? Colors.amber : Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              loc.gameOver,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _statRow(loc.finalScore, '${result.score}'),
            _statRow(loc.gameAccuracy, '${(result.accuracy * 100).toStringAsFixed(1)}%'),
            _statRow(loc.hits, '${result.hits}'),
            _statRow(loc.misses, '${result.misses}'),
            _statRow(loc.sessionDuration, '${result.duration.inSeconds}s'),
            _statRow(loc.difficultyLevel, '${result.difficultyLevel}'),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // Game Hub까지 팝
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.list),
                  label: Text(loc.backToHub),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // 두 단계 뒤로 (결과 → 게임 세팅)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.replay),
                  label: Text(loc.playAgain),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
