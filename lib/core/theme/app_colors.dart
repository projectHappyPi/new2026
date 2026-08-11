import 'package:flutter/material.dart';

/// 머리맡 계기판 컨셉의 기본 색 토큰. 순수 검정(#000000)은 쓰지 않는다 —
/// 따뜻한 계열의 다크가 어두운 방에서 눈에 덜 자극적이다.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color outline;
  final Color outlineSoft;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color muted;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.outlineSoft,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.muted,
  });

  static const dark = AppColors(
    background: Color(0xFF15110F),
    surface: Color(0xFF1E1917),
    surfaceVariant: Color(0xFF292220),
    outline: Color(0xFF38302C),
    outlineSoft: Color(0xFF2A2421),
    onSurface: Color(0xFFF1E9E0),
    onSurfaceVariant: Color(0xFFB8ABA1),
    muted: Color(0xFF7F736A),
  );

  static const light = AppColors(
    background: Color(0xFFF4EFE8),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEBE3D8),
    outline: Color(0xFFD8CCBD),
    outlineSoft: Color(0xFFE6DDD1),
    onSurface: Color(0xFF241D18),
    onSurfaceVariant: Color(0xFF5E5349),
    muted: Color(0xFF8C8075),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? outline,
    Color? outlineSoft,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? muted,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      outline: outline ?? this.outline,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      muted: muted ?? this.muted,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
