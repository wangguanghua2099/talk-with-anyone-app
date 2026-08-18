// 抽屉底部：服务器信息 + 断开连接
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/app_strings.dart';
import '../../screens/connect_screen.dart';
import '../../state/app_state.dart';
import '../../theme.dart';

class DrawerServerFooter extends StatelessWidget {
  const DrawerServerFooter({
    super.key,
    required this.baseUrl,
    required this.version,
  });

  final String baseUrl;
  final String version;

  @override
  Widget build(BuildContext context) {
    final strs = context.strs;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$strs.server\n$baseUrl',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                version,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await context.read<AppState>().disconnect();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ConnectScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.link_off, size: 18),
              label: Text(strs.disconnect),
            ),
          ),
        ],
      ),
    );
  }
}