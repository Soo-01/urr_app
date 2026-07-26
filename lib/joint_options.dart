import 'generated/l10n.dart';

const rehabilitationJointCodes = <String>[
  'lShoulderEF',
  'lShoulderRo',
  'lElbow',
  'lWrist',
  'rShoulderEF',
  'rShoulderRo',
  'rElbow',
  'rWrist',
];

String localizedJointLabel(String code, AppLocalizations loc) {
  return switch (code) {
    'lShoulderEF' => loc.lShoulderEF,
    'lShoulderRo' => loc.lShoulderRo,
    'lElbow' => loc.lElbow,
    'lWrist' => loc.lWrist,
    'rShoulderEF' => loc.rShoulderEF,
    'rShoulderRo' => loc.rShoulderRo,
    'rElbow' => loc.rElbow,
    'rWrist' => loc.rWrist,
    _ => code,
  };
}
