import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/game_catalog.dart';

class GamePickerPage extends StatefulWidget {
  const GamePickerPage({super.key});
  @override
  State<GamePickerPage> createState() => _GamePickerPageState();
}

class _GamePickerPageState extends State<GamePickerPage> {
  String query = '', platform = '';
  @override
  Widget build(BuildContext context) {
    final matches = searchGames(
      query,
    ).where((g) => platform.isEmpty || g.platform == platform).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('게임 찾기')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: '게임·시리즈 검색',
                  hintText: '포켓몬 / 파엠 / 페르소나',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in {
                  '': '전체',
                  'Nintendo Switch': 'Switch',
                  'Nintendo Switch 2': 'Switch 2',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: platform == entry.key,
                    onSelected: (_) => setState(() => platform = entry.key),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('수록 ${gameCatalog.length}개 작품 · 전체 출시 목록은 아닙니다.'),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('수록된 작품이 없습니다. 직접 추가할 수 있습니다.'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final game = matches[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          title: Text(game.name),
                          subtitle: Text(
                            '${game.platform}${game.verifyAvailability ? ' · 발매·공략 공개 여부 확인 필요' : ''}',
                          ),
                          onTap: () => Navigator.pop(context, game),
                          trailing: IconButton(
                            tooltip: '${game.name} 공식 사이트',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () async {
                              try {
                                await launchUrl(
                                  Uri.parse(game.reference),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('공식 사이트를 열 수 없습니다.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, genericGame),
                icon: const Icon(Icons.add),
                label: const Text('목록에 없는 게임 직접 추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
