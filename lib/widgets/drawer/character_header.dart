// 抽屉顶部：当前角色头像 + 名字 + 提示
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../avatar.dart';

class DrawerCharacterHeader extends StatelessWidget {
  const DrawerCharacterHeader({
    super.key,
    required this.avatarData,
    required this.name,
    required this.hint,
  });

  final String? avatarData;
  final String name;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          AppAvatar(
            dataUri: avatarData,
            name: name,
            radius: 26,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}