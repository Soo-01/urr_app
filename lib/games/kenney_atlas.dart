import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';

/// ============================================================================
/// KenneyAtlas — Kenney TextureAtlas XML 파서 + Sprite 캐시
///
/// Kenney 스프라이트시트는 다음 XML 포맷을 사용합니다:
///   <TextureAtlas imagePath="sheet.png">
///     <SubTexture name="fish_blue" x="576" y="128" width="64" height="64"/>
///     ...
///   </TextureAtlas>
///
/// 사용법:
///   // 초기화 (앱 시작 또는 게임 onLoad에서 1회)
///   final atlas = await KenneyAtlas.load(
///     xmlPath: 'kenney_fish-pack_2/Spritesheet/spritesheet.xml',
///     imagePath: 'kenney_fish-pack_2/Spritesheet/spritesheet.png',
///   );
///
///   // 이름으로 Sprite 가져오기
///   final fishBlue = atlas.sprite('fish_blue');
///   final fishRed  = atlas.sprite('fish_red');
///   final bubble   = atlas.sprite('bubble_a');
///
///   // Flame 컴포넌트에 바로 사용
///   final comp = SpriteComponent(sprite: atlas.sprite('fish_orange'));
/// ============================================================================

class KenneyAtlas {
  final ui.Image image;
  final Map<String, _SubTexture> _map;

  KenneyAtlas._(this.image, this._map);

  // ─── 전역 캐시 (팩당 1개) ───
  static final Map<String, KenneyAtlas> _cache = {};

  /// XML + 이미지 로드. 동일 xmlPath는 캐시에서 반환.
  static Future<KenneyAtlas> load({
    required String xmlPath,
    required String imagePath,
  }) async {
    if (_cache.containsKey(xmlPath)) return _cache[xmlPath]!;

    // XML 문자열 로드 (에셋은 assets/images/ 아래에 위치)
    final xmlStr = await rootBundle.loadString('assets/images/$xmlPath');

    // 이미지 로드 (에셋은 assets/images/ 아래에 위치 — Flame 기본 경로)
    final img = await Flame.images.load(imagePath);

    // 파싱
    final map = _parseXml(xmlStr);
    final atlas = KenneyAtlas._(img, map);
    _cache[xmlPath] = atlas;
    return atlas;
  }

  /// 캐시 비우기 (필요 시)
  static void clearCache() => _cache.clear();

  // ─── Sprite 접근 ───

  /// 이름으로 Sprite 반환. 없으면 null.
  Sprite? spriteOrNull(String name) {
    final st = _map[name] ?? _map['${name}.png'];
    if (st == null) return null;
    return Sprite(image,
        srcPosition: Vector2(st.x.toDouble(), st.y.toDouble()),
        srcSize: Vector2(st.w.toDouble(), st.h.toDouble()));
  }

  /// 이름으로 Sprite 반환. 없으면 AssertionError.
  Sprite sprite(String name) {
    final s = spriteOrNull(name);
    assert(s != null, 'KenneyAtlas: "$name" not found. Available: ${_map.keys.take(5).join(', ')}...');
    return s!;
  }

  /// 접두사로 시작하는 모든 스프라이트 목록 반환 (예: 'fish_')
  List<Sprite> spritesByPrefix(String prefix) {
    return _map.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => Sprite(image,
            srcPosition: Vector2(e.value.x.toDouble(), e.value.y.toDouble()),
            srcSize: Vector2(e.value.w.toDouble(), e.value.h.toDouble())))
        .toList();
  }

  /// 모든 키 목록
  List<String> get keys => _map.keys.toList();

  // ─── XML 파서 (정규식, 외부 패키지 불필요) ───

  static Map<String, _SubTexture> _parseXml(String xml) {
    final map = <String, _SubTexture>{};

    // <SubTexture name="..." x="N" y="N" width="N" height="N"/>
    final pattern = RegExp(
      r'<SubTexture\s+'
      r'name="([^"]+)"\s+'
      r'x="(\d+)"\s+'
      r'y="(\d+)"\s+'
      r'width="(\d+)"\s+'
      r'height="(\d+)"',
    );

    for (final m in pattern.allMatches(xml)) {
      final name = m.group(1)!;
      final st = _SubTexture(
        x: int.parse(m.group(2)!),
        y: int.parse(m.group(3)!),
        w: int.parse(m.group(4)!),
        h: int.parse(m.group(5)!),
      );
      map[name] = st;
      // .png 없는 버전도 등록 (kenney마다 확장자 유무가 다름)
      if (name.endsWith('.png')) {
        map[name.substring(0, name.length - 4)] = st;
      }
    }
    return map;
  }
}

class _SubTexture {
  final int x, y, w, h;
  const _SubTexture({required this.x, required this.y, required this.w, required this.h});
}

// ─── 자주 쓰는 팩 상수 ───

/// Fish Pack 2 스프라이트시트
class FishAtlas {
  static const String xmlPath = 'kenney_fish-pack_2/Spritesheet/spritesheet.xml';
  static const String imgPath = 'kenney_fish-pack_2/Spritesheet/spritesheet.png';

  // 수집 물고기 이름 목록 (밝은 색상 위주)
  static const List<String> collectibles = [
    'fish_blue', 'fish_orange', 'fish_pink', 'fish_red', 'fish_green',
  ];

  // 장애물 해골물고기 이름 목록
  static const List<String> obstacles = [
    'fish_blue_skeleton', 'fish_green_skeleton',
    'fish_orange_skeleton', 'fish_pink_skeleton', 'fish_red_skeleton',
  ];

  // 배경 해조류 이름 목록 (XML 실제 이름: background_seaweed_a~h)
  static const List<String> seaweeds = [
    'background_seaweed_a', 'background_seaweed_b', 'background_seaweed_c',
    'background_seaweed_d', 'background_seaweed_e',
  ];

  // 기포
  static const List<String> bubbles = ['bubble_a', 'bubble_b', 'bubble_c'];

  // 배경 바위
  static const List<String> rocks = ['background_rock_a', 'background_rock_b'];

  static Future<KenneyAtlas> load() =>
      KenneyAtlas.load(xmlPath: xmlPath, imagePath: imgPath);
}

/// Sports Pack 장비 스프라이트시트
class SportsAtlas {
  static const String xmlPath = 'kenney_sports-pack/Spritesheet/sheet_equipment.xml';
  static const String imgPath = 'kenney_sports-pack/Spritesheet/sheet_equipment.png';

  // 볼링공 (회전 프레임 3개)
  static const List<String> bowlingBalls = [
    'ball_bowling1', 'ball_bowling2', 'ball_bowling3',
  ];

  static Future<KenneyAtlas> load() =>
      KenneyAtlas.load(xmlPath: xmlPath, imagePath: imgPath);
}

/// Rolling Ball Assets 스프라이트시트 (레인/배경)
class RollingBallAtlas {
  static const String xmlPath = 'kenney_rolling-ball-assets/Spritesheet/rollingBall_sheet.xml';
  static const String imgPath = 'kenney_rolling-ball-assets/Spritesheet/rollingBall_sheet.png';

  // 배경 타일 (레인 색상)
  static const List<String> backgrounds = [
    'background_blue', 'background_brown', 'background_green',
  ];

  // 공 스프라이트 (64×64 — 고화질)
  static const List<String> balls = [
    'ball_red_large', 'ball_red_large_alt',
  ];

  static Future<KenneyAtlas> load() =>
      KenneyAtlas.load(xmlPath: xmlPath, imagePath: imgPath);
}
