import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/app_state_provider.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late TextEditingController _portCtl;
  late TextEditingController _storePathCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final appState = ref.read(appStateProvider);
    _portCtl = TextEditingController(text: appState.backendPort);
    final storePath = appState.storePath;
    _storePathCtl = TextEditingController(
      text: storePath.isNotEmpty ? File(storePath).absolute.path : 'data/store.json',
    );
  }

  @override
  void dispose() {
    _portCtl.dispose();
    _storePathCtl.dispose();
    super.dispose();
  }

  Future<void> _pickStorePath() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '选择数据文件保存位置',
      fileName: 'store.json',
    );
    if (result != null && mounted) {
      setState(() => _storePathCtl.text = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    return AlertDialog(
      title: const Text('设置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appState.backendAddress.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('当前监听: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(appState.backendAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _portCtl,
              decoration: const InputDecoration(
                labelText: '后端监听端口',
                helperText: '留空=随机端口，或输入固定端口号',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _storePathCtl,
                    decoration: const InputDecoration(
                      labelText: '数据文件路径',
                      helperText: '绝对路径或相对路径',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: '选择文件',
                  onPressed: _pickStorePath,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final notifier = ref.read(appStateProvider.notifier);
                  await notifier.updateBackendPort(_portCtl.text.trim());
                  notifier.setStorePath(_storePathCtl.text.trim());
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存并重启'),
        ),
      ],
    );
  }
}