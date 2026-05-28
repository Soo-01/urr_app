import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'generated/l10n.dart';
import 'bluetooth.dart';

class UploadFileSlot {
  final String originalName;
  String? uploadedPath;

  UploadFileSlot({required this.originalName, this.uploadedPath});

  String get displayName => uploadedPath != null ? File(uploadedPath!).path.split('/').last : originalName;
  String get sendingName => '${originalName.split('.csv')[0]}_test.csv';
  Future<File> get currentFile async {
    if (uploadedPath != null) {
      return File(uploadedPath!);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$originalName');
    }
  }

  void reset() {
    uploadedPath = null;
  }
  bool get isUploaded => uploadedPath != null;
}

class FileUploadScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final Function(List<FileSystemEntity>) onFilesChanged;
  final Function(FileSystemEntity) onFilesSent;

  const FileUploadScreen({
    super.key,
    required this.bluetoothService,
    required this.onFilesChanged,
    required this.onFilesSent,
  });

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  List<UploadFileSlot> _slots = [];
  String _statusMessage = '';
  bool _sending = false;
  bool _sent = false;

  final Map<String, String> _originalFiles = {
    'ONESTEP_LEVELWALKING_0.7vel_L_fit.csv': 'assets/ONESTEP_LEVELWALKING_0.7vel_L_fit.csv',
    'ONESTEP_LEVELWALKING_0.7vel_R_fit.csv': 'assets/ONESTEP_LEVELWALKING_0.7vel_R_fit.csv',
    'StandToSit_STS_L_fit.csv': 'assets/StandToSit_STS_L_fit.csv',
    'StandToSit_STS_R_fit.csv': 'assets/StandToSit_STS_R_fit.csv',
    'Stand_bringLeg_L.csv': 'assets/Stand_bringLeg_L.csv',
    'Stand_bringLeg_R.csv': 'assets/Stand_bringLeg_R.csv',
    'walk_L_1st.csv': 'assets/walk_L_1st.csv',
    'walk_R_1st.csv': 'assets/walk_R_1st.csv',
  };

  @override
  void initState() {
    super.initState();
    _initializeSlots();
  }

  Future<void> _initializeSlots() async {
    final dir = await getApplicationDocumentsDirectory();

    for (var entry in _originalFiles.entries) {
      final file = File('${dir.path}/${entry.key}');
      if (!(await file.exists())) {
        final data = await rootBundle.load(entry.value);
        await file.writeAsBytes(data.buffer.asUint8List());
      }
    }

    _slots = _originalFiles.keys.map((name) => UploadFileSlot(originalName: name)).toList();
    setState(() {});
  }

  Future<void> _pickFile(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _slots[index].uploadedPath = result.files.first.path;
      });
    }
  }

  Future<void> _resetToOriginalFiles() async {
    for (var slot in _slots) {
      slot.reset();
    }

    final bluetooth = widget.bluetoothService;
    await bluetooth.sendBytes(Uint8List.fromList("mode:E\n".codeUnits));

    setState(() {});
  }

  Future<void> _sendFiles() async {
    setState(() {
      _sending = true;
      _sent = false;
      _statusMessage = '';
    });

    final bluetooth = widget.bluetoothService;
    bool success = true;

    for (final slot in _slots) {
      final file = await slot.currentFile;
      final filename = slot.sendingName;

      final header = Uint8List.fromList("FILE:$filename\n".codeUnits);
      final fileBytes = await file.readAsBytes();
      final terminator = Uint8List.fromList("EOF\n".codeUnits);

      final fullData = Uint8List(header.length + fileBytes.length + terminator.length);
      fullData.setAll(0, header);
      fullData.setAll(header.length, fileBytes);
      fullData.setAll(header.length + fileBytes.length, terminator);

      try {
        success &= await bluetooth.sendBytes(fullData);
        await Future.delayed(const Duration(seconds: 1));
      } catch (_) {
        success = false;
      }
    }
    final modeData1 = Uint8List.fromList("mode:Z\n".codeUnits);
    final modeData2 = Uint8List.fromList("traj:csv\n".codeUnits);

    success &= await bluetooth.sendBytes(modeData1);
    await Future.delayed(const Duration(milliseconds: 300));
    success &= await bluetooth.sendBytes(modeData2);

    // if (success) _resetSlots();

    setState(() {
      _sending = false;
      _sent = true;
      _statusMessage = success
          ? AppLocalizations.of(context)!.fileSentSuccess
          : AppLocalizations.of(context)!.fileSentFail;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _sent = false;
          _statusMessage = '';
        });
      }
    });
  }

  void _resetSlots() {
    for (var slot in _slots) {
      slot.reset();
    }
    setState(() {});  
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.fileUploadSend)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                return ListTile(
                  title: Text(
                    slot.displayName,
                    style: TextStyle(
                      color: slot.isUploaded ? Colors.green : null,
                      fontWeight: slot.isUploaded ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(slot.sendingName),
                  trailing: ElevatedButton(
                    onPressed: () => _pickFile(index),
                    child: Text(loc.upload),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _sending ? null : _sendFiles,
                  icon: Icon(Icons.save, color: _sending || _sent ? Colors.blue : null),
                  label: Text(loc.sendFiles),
                ),
                const SizedBox(width: 16),
                if (_sending) 
                  Row(children: [
                    const Icon(Icons.sync, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(loc.loading, style: const TextStyle(color: Colors.blue)),
                  ])
                else if (_sent && _statusMessage.contains(loc.fileSentFail))
                  Row(children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(loc.fileSentFail, style: const TextStyle(color: Colors.red)),
                  ]),
                const Spacer(),
                TextButton(
                  onPressed: _resetToOriginalFiles,
                  child: Text(loc.reset),
                ),
              ],
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _statusMessage.contains(loc.fileSentFail) ? Colors.red : Colors.green,
                )
              )
            )
        ],
      ),
    );
  }
}


