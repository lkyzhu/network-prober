import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/probe_item.dart';
import '../../models/probe_result.dart';
import '../../providers/app_state_provider.dart';
import '../modals/item_dialogs.dart';

class ItemRowWidget extends ConsumerStatefulWidget {
  final ProbeItem item;

  const ItemRowWidget({super.key, required this.item});

  @override
  ConsumerState<ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends ConsumerState<ItemRowWidget> {
  bool _detailExpanded = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final results = appState.results[widget.item.id];
    final probeResult = results != null && results.isNotEmpty ? results.first : null;
    final isSelected = appState.isItemSelected(widget.item.id);

    Color statusColor;
    if (probeResult == null) {
      statusColor = Colors.grey;
    } else if (probeResult.successCount == probeResult.totalTargets && probeResult.totalTargets > 0) {
      statusColor = Colors.green;
    } else if (probeResult.successCount > 0) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withValues(alpha: 0.05) : null,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: InkWell(
            onTap: () => ref.read(appStateProvider.notifier).toggleItemSelection(widget.item.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Checkbox
                  SizedBox(
                    width: 50,
                    child: Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16, color: isSelected ? Colors.blue : Colors.grey[400],
                    ),
                  ),
                  // Address
                  Expanded(flex: 3, child: Text(widget.item.address, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  // Protocol badge
                  Expanded(flex: 1, child: Center(child: _buildProtocolBadge(context))),
                  // Probe type
                  Expanded(flex: 1, child: Text(widget.item.probeType, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                  // Cert
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: widget.item.certData != null && widget.item.certData!.isNotEmpty
                          ? Text('自定义', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                          : Text('系统', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ),
                  ),
                  // Actions
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => showEditItemDialog(context, ref, widget.item),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('编辑', style: TextStyle(fontSize: 11, color: Colors.blue[600])),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Result
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: probeResult != null
                          ? () => setState(() => _detailExpanded = !_detailExpanded)
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          if (probeResult != null)
                            Text('${probeResult.successCount}/${probeResult.totalTargets}', style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500))
                          else
                            Text('未探测', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          if (probeResult != null) ...[
                            const SizedBox(width: 4),
                            Icon(_detailExpanded ? Icons.expand_less : Icons.expand_more, size: 14, color: Colors.grey),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Inline result summary (matching web .inline-result)
        if (probeResult != null && _detailExpanded)
          _buildInlineResult(context, probeResult, appState),
      ],
    );
  }

  Widget _buildProtocolBadge(BuildContext context) {
    Color color;
    switch (widget.item.protocol) {
      case 'tcp': color = Colors.blue; break;
      case 'http': color = Colors.green; break;
      case 'udp': color = Colors.orange; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        widget.item.protocol.toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInlineResult(BuildContext context, ProbeResult result, dynamic appState) {
    final okCount = result.results.where((r) => r.success).length;
    final failCount = result.results.where((r) => !r.success).length;
    final total = result.results.length;

    String statusLabel;
    Color statusColor;
    if (okCount == total && total > 0) {
      statusLabel = '全部成功';
      statusColor = Colors.green;
    } else if (failCount == total) {
      statusLabel = '全部失败';
      statusColor = Colors.red;
    } else {
      statusLabel = '部分成功($okCount/$total)';
      statusColor = Colors.orange;
    }

    // Calculate averages
    final avgDns = result.results.isEmpty
        ? 0.0
        : result.results.map((r) => (r.dnsLookupMs ?? 0).toDouble()).reduce((a, b) => a + b) / result.results.length;
    final avgConn = result.results.isEmpty
        ? 0.0
        : result.results.map((r) => (r.connectMs ?? 0).toDouble()).reduce((a, b) => a + b) / result.results.length;
    final avgRtt = result.results.isEmpty
        ? 0.0
        : result.results.map((r) => (r.rttMs ?? 0).toDouble()).reduce((a, b) => a + b) / result.results.length;

    final firstWithCert = result.results.cast<SingleProbeResult?>().firstWhere(
      (r) => r!.cert != null,
      orElse: () => null,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(62, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _metric('DNS', '${avgDns.toStringAsFixed(1)}ms'),
              const SizedBox(width: 8),
              _metric('连接', '${avgConn.toStringAsFixed(1)}ms'),
              const SizedBox(width: 8),
              _metric('首包', '${avgRtt.toStringAsFixed(1)}ms'),
              if (firstWithCert != null) ...[
                const SizedBox(width: 8),
                _metric('证书', firstWithCert.cert!.verified ? '已验证' : '未验证',
                  color: firstWithCert.cert!.verified ? Colors.green : Colors.orange),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Detail rows (matching web .inline-detail)
          ...result.results.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(r.target, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                ),
                Icon(
                  r.success ? Icons.check_circle : Icons.error,
                  size: 12, color: r.success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                if (r.dnsLookupMs != null)
                  _metric('DNS', '${r.dnsLookupMs}ms'),
                if (r.dnsLookupMs != null) const SizedBox(width: 8),
                if (r.connectMs != null)
                  _metric('连接', '${r.connectMs}ms'),
                if (r.connectMs != null) const SizedBox(width: 8),
                if (r.rttMs != null)
                  _metric('耗时', '${r.rttMs}ms'),
                if (r.statusCode != null) ...[
                  const SizedBox(width: 8),
                  _metric('状态码', '${r.statusCode}'),
                ],
                if (r.error != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.error!, style: const TextStyle(fontSize: 11, color: Colors.red), overflow: TextOverflow.ellipsis),
                  ),
                ],
                if (r.cert != null)
                  IconButton(
                    icon: const Icon(Icons.verified, size: 14, color: Colors.blue),
                    tooltip: '证书信息',
                    onPressed: () => _showCertInfo(context, r.cert!),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  void _showCertInfo(BuildContext context, dynamic cert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('证书信息'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _certRow('主题', cert.subject),
              _certRow('颁发者', cert.issuer),
              _certRow('有效期开始', cert.notBefore),
              _certRow('有效期结束', cert.notAfter),
              _certRow('指纹', cert.fingerprint),
              _certRow('验证状态', cert.verified ? '通过' : '失败'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }

  Widget _certRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
