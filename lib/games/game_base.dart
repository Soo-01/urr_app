import 'angle_normalizer.dart';

/// 게임 진행 상태
enum GameState { calibrating, countdown, playing, paused, finished }

/// Brunnstrom 회복 단계 (편마비 환자)
enum BrunnstromStage {
  stage2(2, 'Stage 2', '경직 시작'),
  stage3(3, 'Stage 3', '공동운동'),
  stage4(4, 'Stage 4', '공동운동 분리 시작'),
  stage5(5, 'Stage 5', '독립적 운동'),
  stage6(6, 'Stage 6', '정상에 가까움');

  final int level;
  final String label;
  final String description;
  const BrunnstromStage(this.level, this.label, this.description);
}

/// 인지 레벨 (시각 복잡도 결정)
enum CognitiveLevel {
  simple(1, '단순', 'MMSE < 20'),
  moderate(2, '보통', 'MMSE 20~25'),
  rich(3, '풍부', 'MMSE > 25');

  final int level;
  final String label;
  final String description;
  const CognitiveLevel(this.level, this.label, this.description);

  /// 파티클 수
  int get particleCount => [0, 5, 15][level - 1];
  /// 오브젝트 크기 배율
  double get sizeMultiplier => [2.0, 1.2, 1.0][level - 1];
  /// HUD 표시 범위
  bool get showCombo => level >= 2;
  bool get showTimer => level >= 2;
  bool get showLives => level >= 3;
  /// 자동 음성 가이드 여부
  bool get autoVoiceGuide => level <= 2;
  /// 배경 복잡도 (0=단색, 1=그라디언트, 2=테마배경)
  int get bgComplexity => level - 1;
}

/// 게임에서 사용하는 모터 모드
enum MotorMode { none, cpm, isometric, isotonic }

/// 게임 설정 (확장)
class GameConfig {
  final AngleNormalizer normalizer;
  final int difficultyLevel; // 1~5 (Brunnstrom 단계 내 세부 난이도)
  final String bodyPart; // 관절 코드 (lShoulderEF, lShoulderRo, lElbow)
  final Duration gameDuration;
  final BrunnstromStage brunnstromStage;
  final CognitiveLevel cognitiveLevel;
  final MotorMode motorMode;
  final String? neglectSide; // 편측 무시 방향 ('left' / 'right' / null)

  const GameConfig({
    required this.normalizer,
    this.difficultyLevel = 1,
    this.bodyPart = '',
    this.gameDuration = const Duration(seconds: 60),
    this.brunnstromStage = BrunnstromStage.stage4,
    this.cognitiveLevel = CognitiveLevel.rich,
    this.motorMode = MotorMode.none,
    this.neglectSide,
  });

  /// Brunnstrom 단계별 ROM 사용 비율
  double get romRatio => const {2: 0.4, 3: 0.6, 4: 0.8, 5: 1.0, 6: 1.0}[brunnstromStage.level] ?? 0.8;

  /// Brunnstrom 단계별 게임 속도 배율 (1.0 = 보통)
  double get speedMultiplier => const {2: 0.4, 3: 0.6, 4: 0.8, 5: 1.0, 6: 1.2}[brunnstromStage.level] ?? 0.8;

  /// Brunnstrom 단계별 타겟 크기 배율
  double get targetSizeMultiplier {
    final brunnstrom = const {2: 2.0, 3: 1.5, 4: 1.2, 5: 1.0, 6: 0.8}[brunnstromStage.level] ?? 1.2;
    return brunnstrom * cognitiveLevel.sizeMultiplier;
  }

  /// CPM 보조 필요 여부
  bool get needsCpmAssist => brunnstromStage.level <= 3;

  /// 등척성/등장성 저항 사용 가능 여부
  bool get canUseResistance => brunnstromStage.level >= 4;
}

/// 각도 기록 (시계열 데이터)
class AngleRecord {
  final int timestampMs;
  final double rawAngle;
  final double normalizedPosition;
  final double? targetPosition;
  final String event;

  const AngleRecord({
    required this.timestampMs,
    required this.rawAngle,
    required this.normalizedPosition,
    this.targetPosition,
    this.event = '',
  });

  Map<String, dynamic> toMap() => {
        'timestamp_ms': timestampMs,
        'raw_angle': rawAngle,
        'normalized_position': normalizedPosition,
        'target_position': targetPosition,
        'event': event,
      };

  String toCsvRow() =>
      '$timestampMs,${rawAngle.toStringAsFixed(2)},${normalizedPosition.toStringAsFixed(4)},${targetPosition?.toStringAsFixed(4) ?? ''},$event';

  static String csvHeader() =>
      'timestamp_ms,raw_angle,normalized_position,target_position,event';
}

/// 게임 세션 결과
class GameResult {
  final String gameId;
  final int score;
  final int maxPossibleScore;
  final double accuracy;
  final Duration duration;
  final int difficultyLevel;
  final String bodyPart;
  final DateTime timestamp;
  final double calibrationMin;
  final double calibrationMax;
  final int hits;
  final int misses;
  final List<AngleRecord> angleHistory;

  const GameResult({
    required this.gameId,
    required this.score,
    required this.maxPossibleScore,
    required this.accuracy,
    required this.duration,
    required this.difficultyLevel,
    required this.bodyPart,
    required this.timestamp,
    required this.calibrationMin,
    required this.calibrationMax,
    this.hits = 0,
    this.misses = 0,
    this.angleHistory = const [],
  });

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'score': score,
        'maxPossibleScore': maxPossibleScore,
        'accuracy': accuracy,
        'durationSeconds': duration.inSeconds,
        'difficultyLevel': difficultyLevel,
        'bodyPart': bodyPart,
        'timestamp': timestamp.toIso8601String(),
        'calibrationMin': calibrationMin,
        'calibrationMax': calibrationMax,
        'hits': hits,
        'misses': misses,
      };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
        gameId: json['gameId'] as String,
        score: json['score'] as int,
        maxPossibleScore: json['maxPossibleScore'] as int,
        accuracy: (json['accuracy'] as num).toDouble(),
        duration: Duration(seconds: json['durationSeconds'] as int),
        difficultyLevel: json['difficultyLevel'] as int,
        bodyPart: json['bodyPart'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        calibrationMin: (json['calibrationMin'] as num).toDouble(),
        calibrationMax: (json['calibrationMax'] as num).toDouble(),
        hits: json['hits'] as int? ?? 0,
        misses: json['misses'] as int? ?? 0,
      );

  String get angleHistoryCsv {
    final buf = StringBuffer()..writeln(AngleRecord.csvHeader());
    for (final r in angleHistory) {
      buf.writeln(r.toCsvRow());
    }
    return buf.toString();
  }
}
