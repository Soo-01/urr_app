import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../bluetooth.dart';
import '../generated/l10n.dart';
import 'angle_normalizer.dart';

/// ROM 캘리브레이션 위젯.
/// 환자가 최대 범위로 팔을 움직이면 min/max를 측정하여 AngleNormalizer를 반환한다.
class CalibrationWidget extends StatefulWidget {
  final BluetoothService bluetoothService;
  final Duration calibrationDuration;
  final ValueChanged<AngleNormalizer> onComplete;

  const CalibrationWidget({
    super.key,
    required this.bluetoothService,
    required this.onComplete,
    this.calibrationDuration = const Duration(seconds: 10),
  });

  @override
  State<CalibrationWidget> createState() => _CalibrationWidgetState();
}

class _CalibrationWidgetState extends State<CalibrationWidget> {
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<String>? _btSubscription;

  double? _currentAngle;
  double? _minAngle;
  double? _maxAngle;
  bool _isMeasuring = false;
  bool _isCountingDown = false;
  int _countdownValue = 3;
  double _progress = 0.0;
  Timer? _progressTimer;

  // 시뮬레이션 모드 (BT 미연결 시)
  bool get _isSimulation => !widget.bluetoothService.isConnected();
  double _simValue = 0.0;

  @override
  void dispose() {
    _btSubscription?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCalibration() async {
    final loc = AppLocalizations.of(context)!;
    final langCode = loc.localeName;

    // 카운트다운
    setState(() => _isCountingDown = true);
    final ttsLang = langCode == 'ko' ? 'ko-KR' : 'en-US';
    await _tts.setLanguage(ttsLang);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      await _tts.speak('$i');
      await _tts.awaitSpeakCompletion(true);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    await _tts.speak(langCode == 'ko' ? '시작!' : 'Start!');

    setState(() {
      _isCountingDown = false;
      _isMeasuring = true;
      _minAngle = null;
      _maxAngle = null;
      _currentAngle = null;
      _progress = 0.0;
    });

    // BT 스트림 구독
    _btSubscription?.cancel();
    _btSubscription = widget.bluetoothService.dataStream.listen((data) {
      final angle = double.tryParse(data.trim());
      if (angle == null || !_isMeasuring) return;
      setState(() {
        _currentAngle = angle;
        if (_minAngle == null || angle < _minAngle!) _minAngle = angle;
        if (_maxAngle == null || angle > _maxAngle!) _maxAngle = angle;
      });
    });

    // 프로그레스 타이머
    final totalMs = widget.calibrationDuration.inMilliseconds;
    const tickMs = 50;
    int elapsed = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      elapsed += tickMs;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = (elapsed / totalMs).clamp(0.0, 1.0);
      });
      if (elapsed >= totalMs) {
        timer.cancel();
        _finishCalibration();
      }
    });
  }

  void _finishCalibration() async {
    _btSubscription?.cancel();
    _progressTimer?.cancel();

    setState(() => _isMeasuring = false);

    final loc = AppLocalizations.of(context)!;
    final langCode = loc.localeName;
    await _tts.speak(langCode == 'ko' ? '캘리브레이션 완료' : 'Calibration complete');

    final min = _minAngle ?? -30.0;
    final max = _maxAngle ?? 30.0;

    widget.onComplete(AngleNormalizer(
      minAngle: min,
      maxAngle: max,
    ));
  }

  // 시뮬레이션 모드에서 사용
  void _onSimSliderChanged(double val) {
    setState(() {
      _simValue = val;
      _currentAngle = val;
      if (_isMeasuring) {
        if (_minAngle == null || val < _minAngle!) _minAngle = val;
        if (_maxAngle == null || val > _maxAngle!) _maxAngle = val;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isMeasuring ? Icons.accessibility_new : Icons.tune,
              size: 64,
              color: _isMeasuring ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 24),

            if (_isCountingDown) ...[
              Text(
                '$_countdownValue',
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
              ),
            ] else if (_isMeasuring) ...[
              Text(
                loc.calibrationInstruction,
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _angleLabel('Min', _minAngle),
                  _angleLabel(loc.currentAngle, _currentAngle),
                  _angleLabel('Max', _maxAngle),
                ],
              ),
              if (_isSimulation) ...[
                const SizedBox(height: 16),
                Text('Simulation Mode', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                Slider(
                  value: _simValue,
                  min: -100,
                  max: 100,
                  onChanged: _onSimSliderChanged,
                ),
              ],
            ] else ...[
              Text(
                loc.calibration,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                loc.calibrationInstruction,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (_isSimulation) ...[
                const SizedBox(height: 8),
                Text(
                  'BT 미연결 — 시뮬레이션 모드',
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSimulation ? _startSimulationCalibration : _startCalibration,
                icon: const Icon(Icons.play_arrow),
                label: Text(loc.startCalibration),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startSimulationCalibration() async {
    setState(() {
      _isCountingDown = false;
      _isMeasuring = true;
      _minAngle = null;
      _maxAngle = null;
      _currentAngle = null;
      _progress = 0.0;
    });

    final totalMs = widget.calibrationDuration.inMilliseconds;
    const tickMs = 50;
    int elapsed = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      elapsed += tickMs;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = (elapsed / totalMs).clamp(0.0, 1.0);
      });
      if (elapsed >= totalMs) {
        timer.cancel();
        _finishCalibration();
      }
    });
  }

  Widget _angleLabel(String label, double? value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          value != null ? '${value.toStringAsFixed(1)}°' : '-',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
