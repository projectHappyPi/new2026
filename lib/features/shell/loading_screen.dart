import 'dart:io';

import 'package:flutter/material.dart';

/// 부트스트랩(DB 초기화·시드 데이터 채우기) 동안 보여주는 로딩 화면.
/// 아기 사진이 저장돼 있으면 함께 보여준다. 앱 다크 정체성을 그대로 쓴다.
class LoadingScreen extends StatelessWidget {
  final String? photoPath;

  const LoadingScreen({super.key, this.photoPath});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF15110F);
    const onSurface = Color(0xFFF1E9E0);
    const onSurfaceVariant = Color(0xFFB8ABA1);
    const outline = Color(0xFF38302C);

    final photo = photoPath;
    return ColoredBox(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF292220),
                border: Border.all(color: outline),
                image: photo != null && File(photo).existsSync()
                    ? DecorationImage(
                        image: FileImage(File(photo)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: photo == null
                  ? const Icon(
                      Icons.child_care_rounded,
                      color: onSurfaceVariant,
                      size: 36,
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            const Text(
              '육아 기록',
              style: TextStyle(
                color: onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
