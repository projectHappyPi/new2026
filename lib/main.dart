import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/db/seed.dart';
import 'features/shell/loading_screen.dart';
import 'providers/activity_provider.dart';
import 'providers/baby_profile_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

/// prefs → (사진이 있으면 곧바로 로딩 화면에 보여줄 수 있음) → DB/시드 순서로
/// 초기화한다. 준비가 끝나면 실제 앱(ParentingLogApp)으로 넘어간다.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  SharedPreferences? _prefs;
  AppDatabase? _db;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await initializeDateFormatting('ko_KR');
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _prefs = prefs);

    final db = AppDatabase();
    await seedIfEmpty(db);
    if (!mounted) return;
    setState(() => _db = db);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null || _db == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: LoadingScreen(photoPath: prefs?.getString(kBabyPhotoPathKey)),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(_db!),
      ],
      child: const ParentingLogApp(),
    );
  }
}
