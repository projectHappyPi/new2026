import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/baby_profile.dart';
import 'settings_provider.dart';

const kBabyNameKey = 'babyName';
const kBabyBirthDateKey = 'babyBirthDateEpoch';
const kBabyPhotoPathKey = 'babyPhotoPath';

class BabyProfileNotifier extends Notifier<BabyProfile> {
  @override
  BabyProfile build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final epoch = prefs.getInt(kBabyBirthDateKey);
    return BabyProfile(
      name: prefs.getString(kBabyNameKey),
      birthDate: epoch != null
          ? DateTime.fromMillisecondsSinceEpoch(epoch)
          : null,
      photoPath: prefs.getString(kBabyPhotoPathKey),
    );
  }

  void setName(String name) {
    state = state.copyWith(name: name);
    ref.read(sharedPreferencesProvider).setString(kBabyNameKey, name);
  }

  void setBirthDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    state = state.copyWith(birthDate: normalized);
    ref
        .read(sharedPreferencesProvider)
        .setInt(kBabyBirthDateKey, normalized.millisecondsSinceEpoch);
  }

  /// 갤러리에서 고른 이미지를 앱 문서 폴더로 복사해 영구 보관한다.
  Future<void> setPhotoFromPath(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final dest = p.join(dir.path, 'baby_photo$ext');

    await _deleteExistingPhoto();
    await File(sourcePath).copy(dest);

    state = state.copyWith(photoPath: () => dest);
    await ref
        .read(sharedPreferencesProvider)
        .setString(kBabyPhotoPathKey, dest);
  }

  Future<void> clearPhoto() async {
    await _deleteExistingPhoto();
    state = state.copyWith(photoPath: () => null);
    await ref.read(sharedPreferencesProvider).remove(kBabyPhotoPathKey);
  }

  Future<void> _deleteExistingPhoto() async {
    final existing = state.photoPath;
    if (existing == null) return;
    final file = File(existing);
    if (await file.exists()) await file.delete();
  }
}

final babyProfileProvider = NotifierProvider<BabyProfileNotifier, BabyProfile>(
  BabyProfileNotifier.new,
);
