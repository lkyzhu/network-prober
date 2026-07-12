import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_provider.dart';
import '../../models/probe_item.dart';
import 'item_row_widget.dart';
import '../modals/import_dialog.dart';


class ItemListWidget extends ConsumerWidget {
  const ItemListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final selectedModuleId = appState.selectedModuleId;

    if (selectedModuleId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_left, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('请选择模块', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    final moduleItems = appState.getItemsForModule(selectedModuleId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar (matching web .toolbar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _ToolbarButton(
                label: '添加检测项',
                color: const Color(0xFF1890ff),
                onPressed: () => _showAddItemDialog(context, ref, selectedModuleId),
              ),
              const SizedBox(width: 6),
              _ToolbarButton(
                label: '导入CSV',
                color: const Color(0xFF13c2c2),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ImportDialog(selectedModuleId: selectedModuleId),
                  );
                },
              ),
              const SizedBox(width: 6),
              if (appState.backendReady)
                _ToolbarButton(
                  label: '开始探测',
                  color: const Color(0xFFff4d4f),
                  onPressed: () async {
                    final ids = appState.selectedItemIds.isNotEmpty
                        ? appState.selectedItemIds.toList()
                        : moduleItems.map((e) => e.id).toList();
                    if (ids.isEmpty) return;
                    await ref.read(appStateProvider.notifier).detectItems(ids);
                  },
                ),
              const SizedBox(width: 6),
              if (appState.selectedItemIds.isNotEmpty)
                _ToolbarButton(
                  label: '删除选中 (${appState.selectedItemIds.length})',
                  color: Colors.orange,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除检测项'),
                        content: Text('确定删除选中的 ${appState.selectedItemIds.length} 个检测项？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () async {
                              for (final id in appState.selectedItemIds) {
                                await ref.read(appStateProvider.notifier).removeItem(id);
                              }
                              ref.read(appStateProvider.notifier).deselectAllItems();
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('删除', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        // Header row (matching web .item-list-header)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: GestureDetector(
                  onTap: () => ref.read(appStateProvider.notifier).toggleSelectAll(),
                  child: Row(
                    children: [
                      Icon(
                        moduleItems.isNotEmpty && appState.selectedItemIds.containsAll(moduleItems.map((e) => e.id))
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16, color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text('全选', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              Expanded(flex: 3, child: Text('探测地址', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
              Expanded(flex: 1, child: Text('协议', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
              Expanded(flex: 1, child: Text('探测类型', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
              Expanded(flex: 1, child: Text('证书', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
              Expanded(flex: 1, child: Text('操作', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
              Expanded(flex: 2, child: Text('结果', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
            ],
          ),
        ),
        // Item list
        Expanded(
          child: moduleItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('暂无检测项', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加检测项'),
                        onPressed: () => _showAddItemDialog(context, ref, selectedModuleId),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: moduleItems.length,
                  itemBuilder: (context, index) {
                    final item = moduleItems[index];
                    return LongPressDraggable<ProbeItem>(
                      data: item,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(item.address, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.4, child: ItemRowWidget(item: item)),
                      child: ItemRowWidget(item: item),
                    );
                  },
                ),
        ),
        if (moduleItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加检测项'),
                onPressed: () => _showAddItemDialog(context, ref, selectedModuleId),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref, int moduleId) {
    final addressCtl = TextEditingController();
    String protocol = 'tcp';
    String probeType = 'regular';
    final certCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加检测项'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressCtl,
                  decoration: const InputDecoration(labelText: '探测地址', hintText: '例如: 8.8.8.8:53'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: protocol,
                  decoration: const InputDecoration(labelText: '协议'),
                  items: const [
                    DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                    DropdownMenuItem(value: 'http', child: Text('HTTP')),
                    DropdownMenuItem(value: 'udp', child: Text('UDP')),
                  ],
                  onChanged: (v) => setDialogState(() => protocol = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: probeType,
                  decoration: const InputDecoration(labelText: '探测类型'),
                  items: const [
                    DropdownMenuItem(value: 'regular', child: Text('Regular')),
                    DropdownMenuItem(value: 'full', child: Text('Full')),
                  ],
                  onChanged: (v) => setDialogState(() => probeType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: certCtl,
                  decoration: const InputDecoration(labelText: '根证书 (可选)'),
                  maxLines: 3,
                  minLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                if (addressCtl.text.trim().isEmpty) return;
                ref.read(appStateProvider.notifier).addItem(
                  addressCtl.text.trim(),
                  protocol,
                  probeType,
                  moduleId,
                  certData: certCtl.text.trim().isEmpty ? null : certCtl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ToolbarButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(label),
      ),
    );
  }
}
