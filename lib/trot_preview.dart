// 임시 프리뷰 진입점 — 게임 허브(게임 선택 + 난이도/설정)로 진입.
// 실행: flutter run -d <device> -t lib/trot_preview.dart
// 게임 허브에서 게임을 고르고 난이도·시간·Brunnstrom 등을 설정한 뒤 시작.
// BT 미연결이면 각 게임이 자동으로 슬라이더(시뮬) 입력 모드로 동작.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'generated/l10n.dart';
import 'bluetooth.dart';
import 'games/game_hub.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: GameHubScreen(bluetoothService: BluetoothService()),
  ));
}
