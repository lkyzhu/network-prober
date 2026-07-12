import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/probe_item.dart';
import '../../models/api_requests.dart';
import '../../providers/app_state_provider.dart';

void showEditItemDialog(BuildContext context, WidgetRef ref, ProbeItem item) {
  final addressCtl = TextEditingController(text: item.address);
  final certCtl = TextEditingController(text: item.certData ?? '');
  String protocol = item.protocol;
  String probeType = item.probeType;
  bool clearCert = false;

  // Fetch full item to get cert data
  ref.read(appStateProvider.notifier).getItem(item.id).then((fullItem) {
    if (fullItem.certData != null && fullItem.certData!.isNotEmpty) {
      certCtl.text = fullItem.certData!;
    }
  }).catchError((_) {});

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('编辑检测项'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressCtl,
                decoration: const InputDecoration(labelText: '探测地址'),
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
                decoration: const InputDecoration(labelText: '根证书'),
                maxLines: 4,
                minLines: 3,
              ),
              CheckboxListTile(
                title: const Text('清除证书'),
                value: clearCert,
                onChanged: (v) => setDialogState(() {
                  clearCert = v!;
                  if (v) certCtl.clear();
                }),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (addressCtl.text.trim().isEmpty) return;
              final req = UpdateItemRequest(
                address: addressCtl.text.trim(),
                protocol: protocol,
                probeType: probeType,
                certData: clearCert ? null : (certCtl.text.trim().isEmpty ? null : certCtl.text.trim()),
                clearCert: clearCert,
              );
              ref.read(appStateProvider.notifier).updateItem(item.id, req);
              Navigator.pop(ctx);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    ),
  );
}
