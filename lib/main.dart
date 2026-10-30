import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/paldea.dart';
import 'services/planner_store.dart';
import 'widgets/planner_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'PokéAPI data',
    ], await rootBundle.loadString('assets/data/POKEAPI-LICENSE.txt'));
  });
  try {
    final data = await PaldeaData.load();
    final store = PlannerStore(await SharedPreferences.getInstance(), data)
      ..load();
    runApp(PaldeaApp(store: store));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '기록을 안전하게 불러오지 못했습니다.\n앱 데이터를 지우지 말고 저장 공간을 확인한 뒤 다시 실행해 주세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaldeaApp extends StatelessWidget {
  const PaldeaApp({super.key, required this.store});
  final PlannerStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final accent = store.edition == 'scarlet'
          ? const Color(0xFFB64140)
          : const Color(0xFF6950A0);
      final scheme = ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: const Color(0xFFFAF8F3),
      );
      return MaterialApp(
        title: '팔데아 플래너',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFFF3F0E9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF3F0E9),
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: scheme.surface,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primaryContainer,
          ),
        ),
        home: PlannerHome(store: store),
      );
    },
  );
}
