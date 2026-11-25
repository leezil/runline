import 'package:flutter/material.dart';

Future<bool> showLoginRequiredDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('로그인이 필요합니다'),
          content: const Text('로그인하면 피드와 클럽을 이용할 수 있어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('카카오 로그인'),
            ),
          ],
        ),
      ) ??
      false;
}
