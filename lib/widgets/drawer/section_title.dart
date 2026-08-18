// 抽屉分组标题（会话 / 工具 / 设置）
import 'package:flutter/material.dart';

import '../../theme.dart';

class DrawerSectionTitle extends StatelessWidget {
  const DrawerSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}