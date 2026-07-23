import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/app_state_provider.dart';
import '../../models/module.dart';
import '../../models/probe_item.dart';

class ModuleTreeNode extends ConsumerStatefulWidget {
  final Module module;
  final List<Module> allModules;
  final List<ProbeItem> items;

  const ModuleTreeNode({
    super.key,
    required this.module,
    required this.allModules,
    required this.items,
  });

  @override
  ConsumerState<ModuleTreeNode> createState() => _ModuleTreeNodeState();
}

class _ModuleTreeNodeState extends ConsumerState<ModuleTreeNode>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  List<Module> get _children => widget.allModules
      .where((m) => m.parentId == widget.module.id)
      .toList();

  List<ProbeItem> get _moduleItems => widget.items
      .where((item) => item.moduleId == widget.module.id)
      .toList();

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _arrowAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _arrowController.forward();
      } else {
        _arrowController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final isSelected = appState.selectedModuleId == widget.module.id;
    final hasChildren = _children.isNotEmpty || _moduleItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LongPressDraggable<Module>(
          data: widget.module,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(widget.module.name, style: const TextStyle(fontSize: 13)),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: _buildNodeContent(context, isSelected, hasChildren, appState),
          ),
          child: DragTarget<ProbeItem>(
            onAcceptWithDetails: (details) {
              final item = details.data;
              ref.read(appStateProvider.notifier).moveItem(
                item.id,
                newModuleId: widget.module.id,
              );
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
                ),
                child: _buildNodeContent(context, isSelected, hasChildren, appState),
              );
            },
          ),
        ),
        if (_expanded) ...[
          ..._children.map((child) => Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ModuleTreeNode(
              module: child,
              allModules: widget.allModules,
              items: widget.items,
            ),
          )),
          ..._moduleItems.map((item) => _buildItemRow(context, item, appState)),
        ],
      ],
    );
  }

  Widget _buildNodeContent(BuildContext context, bool isSelected, bool hasChildren, dynamic appState) {
    final theme = Theme.of(context);
    final itemCount = _moduleItems.length;
    final moduleCount = _children.length;

    return InkWell(
      onTap: () {
        ref.read(appStateProvider.notifier).selectedModuleId = widget.module.id;
        if (hasChildren) _toggleExpand();
      },
      onSecondaryTap: () => _showContextMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: hasChildren
                  ? GestureDetector(
                      onTap: () => _toggleExpand(),
                      child: RotationTransition(
                        turns: _arrowAnimation,
                        child: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      ),
                    )
                  : const SizedBox(width: 16),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? Icons.folder_open : Icons.folder,
              size: 16,
              color: isSelected ? theme.colorScheme.primary : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.module.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (itemCount > 0 || moduleCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${itemCount + moduleCount}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, ProbeItem item, dynamic appState) {
    final status = appState.getResultStatus(item.id);
    Color dotColor;
    switch (status) {
      case 2: dotColor = Colors.green; break;
      case 1: dotColor = Colors.orange; break;
      case 0: dotColor = Colors.red; break;
      default: dotColor = Colors.grey;
    }

    final protoLabel = item.protocol.toUpperCase();

    final rowContent = Padding(
      padding: const EdgeInsets.only(left: 32, right: 8, top: 3, bottom: 3),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.address,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              protoLabel,
              style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

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
      childWhenDragging: Opacity(opacity: 0.4, child: rowContent),
      child: rowContent,
    );
  }

  void _showContextMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          child: const Text('添加子模块'),
          onTap: () => _showAddSubModuleDialog(context),
        ),
        PopupMenuItem<void>(
          child: const Text('重命名'),
          onTap: () => _showRenameDialog(context),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          child: const Text('导出'),
          onTap: () => _exportModule(context),
        ),
        PopupMenuItem<void>(
          child: const Text('导入'),
          onTap: () => _importModule(context),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          child: const Text('删除模块', style: TextStyle(color: Colors.red)),
          onTap: () => _showDeleteConfirmDialog(context),
        ),
      ],
    );
  }

  void _showAddSubModuleDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加子模块'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '模块名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(appStateProvider.notifier).addModule(controller.text.trim(), parentId: widget.module.id);
                setState(() => _expanded = true);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.module.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名模块'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref.read(appStateProvider.notifier).renameModule(widget.module.id, controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportModule(BuildContext context) async {
    try {
      final data = await ref.read(appStateProvider.notifier).exportModule(widget.module.id);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出模块',
        fileName: '${widget.module.name}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null) {
        File(result).writeAsStringSync(jsonStr);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导出到 $result'), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importModule(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入模块',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final jsonStr = file.readAsStringSync();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Determine parent: if imported root name matches this module's name -> merge at same level
      // otherwise -> import as child of this module
      final parentId = data['name'] == widget.module.name
          ? widget.module.parentId
          : widget.module.id;

      await ref.read(appStateProvider.notifier).importModule({
        'parent_id': parentId,
        'modules': [data],
      });
      if (context.mounted) {
        setState(() => _expanded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入成功'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模块'),
        content: const Text('确定删除此模块及其所有子模块和检测项？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(appStateProvider.notifier).removeModule(widget.module.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
