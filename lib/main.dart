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

/// 로딩 화면(아기 사진)이 눈에 띄게 보이도록 최소한 이만큼은 띄워둔다.
/// 실제 DB/시드 초기화는 이 시간과 병렬로 진행되므로, 초기화가 더 오래 걸리는
/// 기기에서도 총 대기 시간은 늘어나지 않는다(더 늦게 끝나는 쪽에 맞춰질 뿐).
const _kSplashMinDuration = Duration(seconds: 3);

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

    final minSplash = Future<void>.delayed(_kSplashMinDuration);
    final db = AppDatabase();
    await Future.wait([seedIfEmpty(db), minSplash]);
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
