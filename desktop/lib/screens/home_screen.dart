import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../widgets/sidebar/module_tree_widget.dart';
import '../widgets/item_list/item_list_widget.dart';
import '../widgets/modals/settings_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastError;
  String _statusText = '就绪';
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(appStateProvider.notifier).initBackend();
    });
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(appStateProvider.notifier).checkBackendHealth();
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    if (appState.error != null && appState.error != _lastError) {
      _lastError = appState.error;
      _statusText = '错误: ${appState.error}';
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${appState.error}'), backgroundColor: Colors.red),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.language, size: 22),
            const SizedBox(width: 8),
            const Text('网络探测工具'),
            const SizedBox(width: 12),
            _buildBackendStatus(appState.backendReady, appState.backendReachable),
          ],
        ),
        actions: [
          if (appState.backendReady)
            _ActionButton(
              icon: Icons.play_arrow,
              label: '探测',
              onPressed: () async {
                final selId = appState.selectedModuleId;
                if (selId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请先选择模块')),
                  );
                  return;
                }
                final itemIds = appState.getItemsForModule(selId).map((e) => e.id).toList();
                if (itemIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该模块下没有检测项')),
                  );
                  return;
                }
                _setStatus('探测中...');
                await ref.read(appStateProvider.notifier).detectItems(itemIds);
                _setStatus('探测完成');
              },
            ),
          if (!appState.backendReady)
            _ActionButton(
              icon: Icons.refresh,
              label: '重启',
              onPressed: () {
                ref.read(appStateProvider.notifier).restartSystemdService();
              },
            ),
          _ActionButton(
            icon: Icons.not_interested,
            label: '清空',
            onPressed: () {
              ref.read(appStateProvider.notifier).clearResults();
              _setStatus('已清空结果');
            },
          ),
          _ActionButton(
            icon: Icons.settings,
            label: '设置',
            onPressed: () => showDialog(context: context, builder: (_) => const SettingsDialog()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: const Row(
              children: [
                SizedBox(width: 280, child: ModuleTreeWidget()),
                VerticalDivider(width: 1),
                Expanded(child: ItemListWidget()),
              ],
            ),
          ),
          // Footer status bar
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                if (appState.loading)
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                if (appState.loading) const SizedBox(width: 8),
                Text(
                  _statusText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  '${appState.items.length} 项',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendStatus(bool ready, bool reachable) {
    final appState = ref.watch(appStateProvider);
    final Color bgColor;
    final Color dotColor;
    final String label;

    if (ready) {
      bgColor = Colors.green.withValues(alpha: 0.15);
      dotColor = Colors.green;
      label = appState.backendAddress.isNotEmpty ? appState.backendAddress : 'Backend OK';
    } else if (reachable) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      dotColor = Colors.orange;
      label = 'Unreachable';
    } else {
      bgColor = Colors.red.withValues(alpha: 0.15);
      dotColor = Colors.red;
      label = 'Starting...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: dotColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
