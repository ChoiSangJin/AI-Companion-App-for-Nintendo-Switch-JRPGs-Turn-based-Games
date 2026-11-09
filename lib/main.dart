import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/compendium.dart';
import 'services/compendium_store.dart';
import 'widgets/fusion_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Megaten Fusion Tools · aqiu384',
    ], await rootBundle.loadString('assets/megaten/UNLICENSE.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'PokéAPI · legacy archive name lookup',
    ], await rootBundle.loadString('assets/archive/POKEAPI-LICENSE.txt'));
  });
  try {
    final games = await GameData.loadAll();
    final store = CompendiumStore(await SharedPreferences.getInstance(), games)
      ..load();
    runApp(AtlusApp(store: store));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '전서 데이터나 기록을 읽지 못했습니다.\n앱 데이터를 지우지 말고 저장 공간을 확인한 뒤 다시 실행해 주세요.',
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

class AtlusApp extends StatelessWidget {
  const AtlusApp({super.key, required this.store});
  final CompendiumStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFFD3B471),
        brightness: Brightness.dark,
        surface: const Color(0xFF192131),
      );
      return MaterialApp(
        title: '합체전서',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFF101622),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF101622),
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: scheme.surface,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
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
        home: FusionHome(store: store),
      );
    },
  );
}
