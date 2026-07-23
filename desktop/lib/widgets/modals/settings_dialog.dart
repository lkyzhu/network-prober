import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/app_state_provider.dart';
import '../../services/backend_service.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late TextEditingController _portCtl;
  late TextEditingController _storePathCtl;
  bool _saving = false;
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    final config = BackendService.loadConfig();
    _portCtl = TextEditingController(text: config.port.toString());
    _storePathCtl = TextEditingController(
      text: config.store.isNotEmpty ? config.store : 'data/store.json',
    );
  }

  @override
  void dispose() {
    _portCtl.dispose();
    _storePathCtl.dispose();
    super.dispose();
  }

  Future<void> _pickStorePath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择数据文件目录',
    );
    if (result != null && mounted) {
      setState(() => _storePathCtl.text = '$result/store.json');
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
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '后端监听端口',
                helperText: '修改后请重启服务以生效',
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
                  tooltip: '选择目录',
                  onPressed: _pickStorePath,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _restarting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(_restarting ? '重启中...' : '重启服务'),
                    onPressed: _restarting ? null : () => _restartService(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
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
                  notifier.setStorePath(_storePathCtl.text.trim());
                  await notifier.updateBackendPort(_portCtl.text.trim());
                  final ok = await notifier.saveConfig();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? '设置已保存' : '设置保存失败（无写入权限）'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _restartService() async {
    setState(() => _restarting = true);
    final notifier = ref.read(appStateProvider.notifier);
    await notifier.restartSystemdService();
    if (mounted) {
      setState(() => _restarting = false);
      if (notifier.backendReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务已重启'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重启失败: ${notifier.error ?? "未知错误"}'), backgroundColor: Colors.red),
        );
      }
      Navigator.pop(context);
    }
  }
}
