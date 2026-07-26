import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth.dart';
import '../generated/l10n.dart';
import '../main.dart';
import '../joint_options.dart';
import 'game_base.dart';
import 'angle_normalizer.dart';
import 'games/target_reaching_game.dart';
import 'games/balloon_pop_game.dart';
import 'games/tracking_game.dart';
import 'games/sky_gardener_game.dart';
import 'games/cloud_painter_game.dart';
import 'games/shield_guard_game.dart';
import 'games/safe_cracker_game.dart';
import 'games/carpenter_game.dart';
import 'games/potion_maker_game.dart';
import 'games/meal_helper_game.dart';
import 'games/swimming_game.dart';
import 'games/bowling_game.dart';

class GameHubScreen extends StatelessWidget {
  final BluetoothService bluetoothService;
  const GameHubScreen({super.key, required this.bluetoothService});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final shoulderGames = [
      _GameInfo(
          id: 'sky_gardener',
          name: loc.skyGardener,
          description: loc.skyGardenerDesc,
          icon: Icons.local_florist,
          color: const Color(0xFF66BB6A),
          joint: 'rShoulderEF'),
      _GameInfo(
          id: 'cloud_painter',
          name: loc.cloudPainter,
          description: loc.cloudPainterDesc,
          icon: Icons.brush,
          color: const Color(0xFF42A5F5),
          joint: 'rShoulderEF'),
      _GameInfo(
          id: 'shield_guard',
          name: loc.shieldGuard,
          description: loc.shieldGuardDesc,
          icon: Icons.shield,
          color: const Color(0xFF78909C),
          joint: 'rShoulderEF'),
      _GameInfo(
          id: 'safe_cracker',
          name: loc.safeCracker,
          description: loc.safeCrackerDesc,
          icon: Icons.lock_open,
          color: const Color(0xFFFFD54F),
          joint: 'rShoulderRo'),
      _GameInfo(
          id: 'star_collector',
          name: loc.targetReaching,
          description: loc.targetReachingDesc,
          icon: Icons.rocket_launch,
          color: const Color(0xFF4FC3F7),
          joint: 'rShoulderEF'),
      _GameInfo(
          id: 'swimming',
          name: loc.swimming,
          description: loc.swimmingDesc,
          icon: Icons.pool,
          color: const Color(0xFF0288D1),
          joint: 'rShoulderEF'),
    ];

    final elbowGames = [
      _GameInfo(
          id: 'brick_breaker',
          name: loc.balloonPop,
          description: loc.balloonPopDesc,
          icon: Icons.grid_view_rounded,
          color: const Color(0xFF00E5FF),
          joint: 'rElbow'),
      _GameInfo(
          id: 'carpenter',
          name: loc.carpenter,
          description: loc.carpenterDesc,
          icon: Icons.carpenter,
          color: const Color(0xFFFF9800),
          joint: 'rElbow'),
      _GameInfo(
          id: 'potion_maker',
          name: loc.potionMaker,
          description: loc.potionMakerDesc,
          icon: Icons.science,
          color: const Color(0xFFAB47BC),
          joint: 'rElbow'),
    ];

    final combinedGames = [
      _GameInfo(
          id: 'meal_helper',
          name: loc.mealHelper,
          description: loc.mealHelperDesc,
          icon: Icons.restaurant,
          color: const Color(0xFFFFB74D),
          joint: 'rShoulderEF+rElbow'),
      _GameInfo(
          id: 'gate_runner',
          name: loc.trackingGame,
          description: loc.trackingGameDesc,
          icon: Icons.sports_esports,
          color: const Color(0xFF81C784),
          joint: 'any'),
      _GameInfo(
          id: 'bowling',
          name: loc.bowling,
          description: loc.bowlingDesc,
          icon: Icons.sports_cricket,
          color: const Color(0xFFFF8F00),
          joint: 'rElbow+rShoulderEF'),
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.rehabGames),
          bottom: TabBar(
            tabs: [
              Tab(
                  icon: const Icon(Icons.accessibility_new),
                  text: loc.categoryShoulder),
              Tab(
                  icon: const Icon(Icons.fitness_center),
                  text: loc.categoryElbow),
              Tab(icon: const Icon(Icons.sync_alt), text: loc.categoryCombined),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GameGrid(
                games: shoulderGames,
                onTap: (id, joint) => _launchSetup(context, id, joint)),
            _GameGrid(
                games: elbowGames,
                onTap: (id, joint) => _launchSetup(context, id, joint)),
            _GameGrid(
                games: combinedGames,
                onTap: (id, joint) => _launchSetup(context, id, joint)),
          ],
        ),
      ),
    );
  }

  void _launchSetup(BuildContext context, String gameId, String joint) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GameSetupScreen(
              bluetoothService: bluetoothService,
              gameId: gameId,
              defaultJoint: joint),
        ));
  }
}

// ─── Game Grid ───

class _GameGrid extends StatelessWidget {
  final List<_GameInfo> games;
  final void Function(String id, String joint) onTap;
  const _GameGrid({required this.games, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12),
        itemCount: games.length,
        itemBuilder: (context, i) {
          final g = games[i];
          return Card(
            elevation: 3,
            child: InkWell(
              onTap: () => onTap(g.id, g.joint),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(g.icon, size: 40, color: g.color),
                      const SizedBox(height: 8),
                      Text(g.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(g.description,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Setup Screen (Brunnstrom + 인지 + 난이도 + 관절) ───

class _GameSetupScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final String gameId;
  final String defaultJoint;
  const _GameSetupScreen(
      {required this.bluetoothService,
      required this.gameId,
      required this.defaultJoint});
  @override
  State<_GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<_GameSetupScreen> {
  int _difficulty = 1;
  int _duration = 60;
  BrunnstromStage _brunnstrom = BrunnstromStage.stage4;
  CognitiveLevel _cognitive = CognitiveLevel.rich;
  String? _neglect;
  late String _joint;
  final TextEditingController _romMinController = TextEditingController();
  final TextEditingController _romMaxController = TextEditingController();
  bool _romInitialized = false;
  String? _selectedRomMode;
  String? _savedRomSummary;

  @override
  void initState() {
    super.initState();
    final defaultJoint = widget.defaultJoint.split('+').first;
    _joint = rehabilitationJointCodes.contains(defaultJoint)
        ? defaultJoint
        : 'rShoulderEF';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_romInitialized && widget.gameId == 'shield_guard') {
      _romInitialized = true;
      _loadRomForSelectedJoint(rebuild: false);
    }
  }

  @override
  void dispose() {
    _romMinController.dispose();
    _romMaxController.dispose();
    super.dispose();
  }

  void _loadRomForSelectedJoint({bool rebuild = true}) {
    final userProvider = context.read<UserProvider>();
    final prom = userProvider.promForPart(_joint);
    final arom = userProvider.aromForPart(_joint);
    final selected = userProvider.measuredRomForPart(_joint);

    void apply() {
      if (selected == null) {
        _romMinController.clear();
        _romMaxController.clear();
        _selectedRomMode = null;
      } else {
        _romMinController.text =
            (selected['minAngle'] as num).toDouble().toStringAsFixed(1);
        _romMaxController.text =
            (selected['maxAngle'] as num).toDouble().toStringAsFixed(1);
        _selectedRomMode = selected['mode']?.toString();
      }
      final summaries = <String>[
        if (prom != null) 'PROM ${_formatRomRange(prom)}',
        if (arom != null) 'AROM ${_formatRomRange(arom)}',
      ];
      _savedRomSummary = summaries.isEmpty ? null : summaries.join(' / ');
    }

    if (rebuild) {
      setState(apply);
    } else {
      apply();
    }
  }

  String _formatRomRange(Map<String, dynamic> rom) {
    final min = (rom['minAngle'] as num).toDouble();
    final max = (rom['maxAngle'] as num).toDouble();
    return '${min.toStringAsFixed(1)}° ~ ${max.toStringAsFixed(1)}°';
  }

  bool isKoreanLocale(AppLocalizations loc) =>
      loc.localeName.toLowerCase().startsWith('ko');

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.startGame)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Brunnstrom 단계
          Text(loc.brunnstromStage,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              children: BrunnstromStage.values
                  .map((s) => ChoiceChip(
                        label: Text(s.label),
                        selected: _brunnstrom == s,
                        onSelected: (_) => setState(() => _brunnstrom = s),
                      ))
                  .toList()),

          const SizedBox(height: 20),
          // 인지 레벨
          Text(loc.selectPart,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _joint,
            items: rehabilitationJointCodes
                .map((code) => DropdownMenuItem(
                      value: code,
                      child: Text(localizedJointLabel(code, loc)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _joint = value);
                if (widget.gameId == 'shield_guard') {
                  _loadRomForSelectedJoint();
                }
              }
            },
          ),
          const SizedBox(height: 20),
          if (widget.gameId == 'shield_guard') ...[
            Text(
              isKoreanLocale(loc) ? '게임 적용 가동 범위' : 'Game ROM range',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_savedRomSummary != null)
              Text(
                '${isKoreanLocale(loc) ? '저장된 ROM' : 'Saved ROM'}: '
                '$_savedRomSummary\n'
                '${isKoreanLocale(loc) ? '자동 선택' : 'Auto selected'}: '
                '${_selectedRomMode ?? '-'}',
              ),
            if (_savedRomSummary == null)
              Text(
                isKoreanLocale(loc)
                    ? '선택한 관절에 저장된 PROM/AROM이 없습니다.'
                    : 'No saved PROM/AROM for the selected joint.',
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _romMinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          isKoreanLocale(loc) ? '최소 각도 (°)' : 'Min angle (°)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _romMaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          isKoreanLocale(loc) ? '최대 각도 (°)' : 'Max angle (°)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isKoreanLocale(loc)
                  ? 'PROM과 AROM 중 더 좁은 범위를 자동 적용합니다. 위 값은 이번 게임에 맞게 수정할 수 있습니다.'
                  : 'The narrower PROM/AROM is selected automatically. You can edit it for this game.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
          ],
          Text(loc.cognitiveLevel,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              children: CognitiveLevel.values
                  .map((c) => ChoiceChip(
                        label: Text(c.label),
                        selected: _cognitive == c,
                        onSelected: (_) => setState(() => _cognitive = c),
                      ))
                  .toList()),

          const SizedBox(height: 20),
          // 편측 무시
          Text(loc.neglectSide,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            ChoiceChip(
                label: Text(loc.neglectNone),
                selected: _neglect == null,
                onSelected: (_) => setState(() => _neglect = null)),
            ChoiceChip(
                label: Text(loc.neglectLeft),
                selected: _neglect == 'left',
                onSelected: (_) => setState(() => _neglect = 'left')),
            ChoiceChip(
                label: Text(loc.neglectRight),
                selected: _neglect == 'right',
                onSelected: (_) => setState(() => _neglect = 'right')),
          ]),

          const SizedBox(height: 20),
          // 난이도
          Text(loc.selectDifficulty,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              children: List.generate(
                  5,
                  (i) => ChoiceChip(
                        label: Text('${i + 1}'),
                        selected: _difficulty == i + 1,
                        onSelected: (_) => setState(() => _difficulty = i + 1),
                      ))),

          const SizedBox(height: 20),
          // 게임 시간
          Text(loc.gameDuration,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              children: [30, 60, 90, 120]
                  .map((s) => ChoiceChip(
                        label: Text(loc.seconds(s)),
                        selected: _duration == s,
                        onSelected: (_) => setState(() => _duration = s),
                      ))
                  .toList()),

          const SizedBox(height: 32),
          Center(
              child: ElevatedButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.play_arrow, size: 28),
            label: Text(loc.startGame, style: const TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
          )),
        ]),
      ),
    );
  }

  void _startGame() {
    final userProvider = context.read<UserProvider>();
    final isKorean =
        AppLocalizations.of(context)!.localeName.toLowerCase().startsWith('ko');
    if (!userProvider.hasRegisteredProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '게임을 시작하기 전에 프로필을 등록하거나 불러와 주세요.'
              : 'Register or load a profile before starting a game.'),
        ),
      );
      return;
    }
    if (!userProvider.hasAnyRomMeasurement) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '게임을 시작하기 전에 PROM 또는 AROM을 측정해 주세요.'
              : 'Measure either PROM or AROM before starting a game.'),
        ),
      );
      return;
    }

    final measuredRom = userProvider.measuredRomForPart(_joint);
    if (widget.gameId == 'shield_guard' && measuredRom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isKorean
              ? '방패 수비대에 사용할 관절의 PROM 또는 AROM을 먼저 측정해 주세요.'
              : 'Measure PROM or AROM for the selected Shield Guard joint first.'),
        ),
      );
      return;
    }
    late final AngleNormalizer normalizer;
    if (widget.gameId == 'shield_guard') {
      final minAngle = double.tryParse(_romMinController.text.trim());
      final maxAngle = double.tryParse(_romMaxController.text.trim());
      if (minAngle == null ||
          maxAngle == null ||
          !minAngle.isFinite ||
          !maxAngle.isFinite ||
          minAngle >= maxAngle) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isKorean
                ? '가동 범위의 최소 각도와 최대 각도를 올바르게 입력해 주세요.'
                : 'Enter a valid ROM range with min angle below max angle.'),
          ),
        );
        return;
      }
      normalizer = AngleNormalizer(
        minAngle: minAngle,
        maxAngle: maxAngle,
      );
    } else {
      normalizer = const AngleNormalizer(minAngle: -100, maxAngle: 100);
    }

    final config = GameConfig(
      normalizer: normalizer,
      difficultyLevel: _difficulty,
      bodyPart: _joint.contains('+') ? _joint.split('+').first : _joint,
      gameDuration: Duration(seconds: _duration),
      brunnstromStage: _brunnstrom,
      cognitiveLevel: _cognitive,
      neglectSide: _neglect,
    );

    Widget screen;
    switch (widget.gameId) {
      case 'sky_gardener':
        screen = SkyGardenerGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'cloud_painter':
        screen = CloudPainterGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'shield_guard':
        screen = ShieldGuardGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'safe_cracker':
        screen = SafeCrackerGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'star_collector':
        screen = TargetReachingGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'brick_breaker':
        screen = BalloonPopGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'carpenter':
        screen = CarpenterGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'potion_maker':
        screen = PotionMakerGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'meal_helper':
        screen = MealHelperGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'gate_runner':
        screen = TrackingGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'swimming':
        screen = SwimmingGame(
            bluetoothService: widget.bluetoothService, config: config);
      case 'bowling':
        screen = BowlingGame(
            bluetoothService: widget.bluetoothService, config: config);
      default:
        return;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _GameInfo {
  final String id, name, description, joint;
  final IconData icon;
  final Color color;
  const _GameInfo(
      {required this.id,
      required this.name,
      required this.description,
      required this.icon,
      required this.color,
      required this.joint});
}
