import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/api_requests.dart';
import '../../providers/app_state_provider.dart';

class ImportDialog extends ConsumerStatefulWidget {
  final int? selectedModuleId;

  const ImportDialog({super.key, this.selectedModuleId});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  int? _selectedModuleId;
  String? _csvContent;
  List<Map<String, String>> _parsedItems = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedModuleId = widget.selectedModuleId;
  }

  void _parseCsv(String content) {
    final lines = content.trim().split('\n');
    final items = <Map<String, String>>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = _parseCsvLine(line);
      if (parts.length >= 3) {
        items.add({
          'address': parts[0].trim(),
          'protocol': parts[1].trim().toLowerCase(),
          'probe_type': parts.length > 2 ? parts[2].trim().toLowerCase() : 'regular',
          'cert_data': parts.length > 3 ? parts[3].trim() : '',
        });
      }
    }
    setState(() {
      _parsedItems = items;
      _csvContent = content;
    });
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final modules = appState.modules;

    return AlertDialog(
      title: const Text('导入CSV'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedModuleId,
                decoration: const InputDecoration(labelText: '目标模块'),
                items: modules.map((m) => DropdownMenuItem(
                  value: m.id,
                  child: Text(m.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedModuleId = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('粘贴CSV内容'),
                      onPressed: () => _showPasteDialog(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.file_open),
                      label: const Text('选择CSV文件'),
                      onPressed: () => _pickFile(context),
                    ),
                  ),
                ],
              ),
              if (_csvContent != null) ...[
                const SizedBox(height: 8),
                Text('已解析 ${_parsedItems.length} 行', style: const TextStyle(color: Colors.green)),
                if (_parsedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('预览:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ..._parsedItems.take(5).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${item['address']} | ${item['protocol']} | ${item['probe_type']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
                  if (_parsedItems.length > 5)
                    Text('... 还有 ${_parsedItems.length - 5} 行', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  if (_selectedModuleId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请选择目标模块')),
                    );
                    return;
                  }
                  if (_parsedItems.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先选择CSV文件或粘贴内容')),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    final importItems = _parsedItems.map((i) => ImportItem(
                      address: i['address']!,
                      protocol: i['protocol']!,
                      probeType: i['probe_type']!,
                      certData: i['cert_data']!.isEmpty ? null : i['cert_data'],
                    )).toList();
                    await ref.read(appStateProvider.notifier).importItems(_selectedModuleId!, importItems);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('导入成功'), backgroundColor: Colors.green),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('导入'),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      final content = await File(file.path!).readAsString();
      _parseCsv(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件选择失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPasteDialog(BuildContext context) {
    final ctl = TextEditingController(text: _csvContent ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴CSV内容'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctl,
            maxLines: 10,
            minLines: 5,
            decoration: const InputDecoration(
              hintText: '探测地址,协议,探测类型,根证书\n8.8.8.8:53,tcp,regular,\n...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (ctl.text.trim().isNotEmpty) {
                _parseCsv(ctl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
