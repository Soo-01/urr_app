import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'generated/l10n.dart';
import 'bluetooth.dart';

class ControlScreen extends StatefulWidget {
  final String arm;
  final double height;
  final double weight;
  final Function(String controlMode, String selectedMode, Map<String, double> gains) onSave;

  const ControlScreen({
    super.key,
    required this.arm,
    required this.height,
    required this.weight,
    required this.onSave,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  String _selectedControlMode = 'PD control';
  bool _isGCEnabled = false;

  final Map<String, double> pdValues = {
    'Left Hip Kp': 50,
    'Left Hip Kd': 1.0,
    'Left Knee Kp': 50,
    'Left Knee Kd': 1.0,
    'Right Hip Kp': 50,
    'Right Hip Kd': 1.0,
    'Right Knee Kp': 50,
    'Right Knee Kd': 1.0,
  };

  final Map<String, double> gcValues = {
    'Left Thigh_gain': 0.5,
    'Left Shank_gain': 0.5,
    'Right Thigh_gain': 0.5,
    'Right Shank_gain': 0.5,
  };

  void _selectControlMode(String mode) => setState(() => _selectedControlMode = mode);

  Future<void> _sendGainData() async {
    final bluetooth = BluetoothService();
    bool overallSuccess = false;

    final controlMode = _selectedControlMode;
    final height = widget.height;
    final weight = widget.weight;

    final values = controlMode == 'PD control'
        ? Map<String, double>.from(pdValues)
        : Map<String, double>.from(gcValues)..['GcompEnabled'] = _isGCEnabled ? 1.0 : 0.0;

    widget.onSave(controlMode, 'N/A', values);

    try {
      bool result = await bluetooth.sendBytes(
        Uint8List.fromList('mode:Z,1.0\n'.codeUnits),
      );
      if (!result) throw Exception('Failed to send mode message');
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (controlMode == 'PD control') {
        final left = 'gain:L,${values['Left Hip Kp']},${values['Left Hip Kd']},${values['Left Knee Kp']},${values['Left Knee Kd']}\n';
        final right = 'gain:R,${values['Right Hip Kp']},${values['Right Hip Kd']},${values['Right Knee Kp']},${values['Right Knee Kd']}\n';

        result = await bluetooth.sendBytes(Uint8List.fromList(left.codeUnits));
        if (!result) throw Exception('Failed to send left gain message');
        await Future.delayed(const Duration(milliseconds: 300));
        result = await bluetooth.sendBytes(Uint8List.fromList(right.codeUnits));
        if (!result) throw Exception('Failed to send right gain message');

      } else if (controlMode == 'Gravity Compensator') {
        final isEnabled = values['GcompEnabled'] == 1.0 ? 1 : 0;
        final left = 'Gcomp:L,$isEnabled,$height,$weight,${values['Left Thigh_gain']},${values['Left Shank_gain']}\n';
        final right = 'Gcomp:R,$isEnabled,$height,$weight,${values['Right Thigh_gain']},${values['Right Shank_gain']}\n';

        result = await bluetooth.sendBytes(Uint8List.fromList(left.codeUnits));
        if (!result) throw Exception('Failed to send left gain message');
        await Future.delayed(const Duration(milliseconds: 300));
        result = await bluetooth.sendBytes(Uint8List.fromList(right.codeUnits));
        if (!result) throw Exception('Failed to send right gain message');
      }

      overallSuccess = true;
      if (!context.mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(overallSuccess
            ? loc.controlGainsSent
            : loc.transmissionFailed),
        ),
      );

    } catch (e) {
      if (!context.mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc?.failedToSendGains ?? 'Failed to send gains'}: $e'),
        ),
      );
    }
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    final isGC = _selectedControlMode == 'Gravity Compensator';
    final isKd = label.contains('Kd');

    double min = isGC ? 0.0 : 0;
    double max = isGC ? 1.0 : 100;
    int? divisions = isGC ? 10 : 100;

    if (!isGC && isKd) {
      min = 0.0;
      max = 5.0;
      divisions = 50; // 0.1 간격
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildControlSettings() {
    if (_selectedControlMode == 'DOB') {
      return const Center(child: Text('DOB has no gain settings'));
    }

    final entries = _selectedControlMode == 'PD control' ? pdValues : gcValues;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: entries.entries.map((entry) {
        return _buildSlider(entry.key, entry.value, (newVal) {
          setState(() => entries[entry.key] = newVal);
        });
      }).toList(),
    );
  }

  Widget _buildGainSide(bool isLeft) {
    final entries = _selectedControlMode == 'PD control'
        ? pdValues.entries
        : gcValues.entries;

    final filtered = entries.where((e) => e.key.startsWith(isLeft ? 'Left' : 'Right')).toList();

    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: filtered.map((entry) {
                return _buildSlider(entry.key, entry.value, (newVal) {
                  setState(() {
                    if (_selectedControlMode == 'PD control') {
                      pdValues[entry.key] = newVal;
                    } else {
                      gcValues[entry.key] = newVal;
                    }
                  });
                });
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isLeft ? (loc?.left ?? 'Left') : (loc?.right ?? 'Right'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (loc == null) {
      return const Scaffold(
        body: Center(child: Text("Localization not loaded")),
      );
    }

    final Map<String, String> modeLabels = {
      'PD control': loc.pdControl,
      'Gravity Compensator': loc.gravityCompensator,
    };
    return Scaffold(
      appBar: AppBar(title: Text(loc.controlScreen)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(loc.controlMode,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: modeLabels.entries.map((entry) {
                    final modeKey = entry.key;
                    final label = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedControlMode == modeKey
                          ? const Color.fromARGB(255, 77, 85, 92)
                          : Colors.grey.shade300,
                          foregroundColor: _selectedControlMode == modeKey ? Colors.white : Colors.black,
                          ), 
                          onPressed: () => _selectControlMode(modeKey),
                          child: Text(label),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedControlMode == 'Gravity Compensator')
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isGCEnabled ? loc.gcOn : loc.gcOff,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Switch(
                            value: _isGCEnabled,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setState(() {
                                _isGCEnabled = val;
                                gcValues['GcompEnabled'] = val ? 1.0 : 0.0;
                              });

                              final bluetooth = BluetoothService();
                              final value = val ? '1.0' : '0.0';

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isGCEnabled
                                      ? loc.gravityCompensatorEnabled
                                      : loc.gravityCompensatorDisabled,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildGainSide(true)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildGainSide(false)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _sendGainData,
                  child: Text(loc.saveGains),
                ),
              ),
            )
          ],
        ),
    );
  }
}