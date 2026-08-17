import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/settings.dart';

/// main()에서 초기화한 인스턴스로 override 된다.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main()에서 override 되어야 합니다');
});

const _kOneHandMode = 'oneHandMode';
const _kHandSide = 'handSide';
const _kThemeOption = 'themeOption';
const _kDarkFrom = 'darkFrom';
const _kDarkTo = 'darkTo';
const _kNightMode = 'nightMode';
const _kNightFrom = 'nightFrom';
const _kNightTo = 'nightTo';
const _kFormulaDefaultMl = 'formulaDefaultMl';
const _kFormulaMode = 'formulaMode';
const _kDiaperDefaultSub = 'diaperDefaultSub';

/// main.dart의 부트스트랩이 Riverpod 없이 곧바로 읽어야 해서 공개 키로 둔다.
const kShowSplashPhotoKey = 'showSplashPhoto';

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return Settings(
      oneHandMode: p.getBool(_kOneHandMode) ?? true,
      handSide: HandSide.values[p.getInt(_kHandSide) ?? HandSide.right.index],
      themeOption: ThemeOption
          .values[p.getInt(_kThemeOption) ?? ThemeOption.system.index],
      darkFrom: TimeHM.parse(p.getString(_kDarkFrom) ?? '20:00'),
      darkTo: TimeHM.parse(p.getString(_kDarkTo) ?? '07:00'),
      nightMode: p.getBool(_kNightMode) ?? false,
      nightFrom: TimeHM.parse(p.getString(_kNightFrom) ?? '22:00'),
      nightTo: TimeHM.parse(p.getString(_kNightTo) ?? '06:00'),
      formulaDefaultMl: p.getInt(_kFormulaDefaultMl) ?? 150,
      formulaMode: FormulaMode
          .values[p.getInt(_kFormulaMode) ?? FormulaMode.fixed.index],
      diaperDefaultSub: DiaperDefaultSub
          .values[p.getInt(_kDiaperDefaultSub) ?? DiaperDefaultSub.pee.index],
      showSplashPhoto: p.getBool(kShowSplashPhotoKey) ?? true,
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  void setOneHandMode(bool v) {
    state = state.copyWith(oneHandMode: v);
    _prefs.setBool(_kOneHandMode, v);
  }

  void setHandSide(HandSide v) {
    state = state.copyWith(handSide: v);
    _prefs.setInt(_kHandSide, v.index);
  }

  void setThemeOption(ThemeOption v) {
    state = state.copyWith(themeOption: v);
    _prefs.setInt(_kThemeOption, v.index);
  }

  void setDarkWindow(TimeHM from, TimeHM to) {
    state = state.copyWith(darkFrom: from, darkTo: to);
    _prefs.setString(_kDarkFrom, from.formatted);
    _prefs.setString(_kDarkTo, to.formatted);
  }

  void setNightMode(bool v) {
    state = state.copyWith(nightMode: v);
    _prefs.setBool(_kNightMode, v);
  }

  void setNightWindow(TimeHM from, TimeHM to) {
    state = state.copyWith(nightFrom: from, nightTo: to);
    _prefs.setString(_kNightFrom, from.formatted);
    _prefs.setString(_kNightTo, to.formatted);
  }

  void setFormulaDefaultMl(int v) {
    state = state.copyWith(formulaDefaultMl: v);
    _prefs.setInt(_kFormulaDefaultMl, v);
  }

  void setFormulaMode(FormulaMode v) {
    state = state.copyWith(formulaMode: v);
    _prefs.setInt(_kFormulaMode, v.index);
  }

  void setDiaperDefaultSub(DiaperDefaultSub v) {
    state = state.copyWith(diaperDefaultSub: v);
    _prefs.setInt(_kDiaperDefaultSub, v.index);
  }

  void setShowSplashPhoto(bool v) {
    state = state.copyWith(showSplashPhoto: v);
    _prefs.setBool(kShowSplashPhotoKey, v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
