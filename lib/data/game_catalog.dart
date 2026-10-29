import '../models/models.dart';

enum GuideTopic {
  roster('roster', '캐릭터 선택', '등장 캐릭터와 가입 조건을 확인하세요'),
  build('build', '추천 직업·육성 경로', '추천 직업과 단계별 전직 조건'),
  party('party', '스토리 추천 파티', '입수 시점·역할·대체 멤버까지'),
  route('route', '추천 진행 순서', '방문 순서와 적정 수준을 한눈에'),
  missables('missables', '놓치기 쉬운 요소', '선택한 구간의 마감·선행 조건');

  const GuideTopic(this.id, this.label, this.description);
  final String id, label, description;
  bool get needsProgress => this == missables;
}

enum GameStyle { tactics, pokemon, calendar, jobs, standard }

class GameDefinition {
  const GameDefinition(
    this.id,
    this.name,
    this.style,
    this.reference, {
    this.aliases = const [],
    this.platform = 'Nintendo Switch',
    this.verifyAvailability = false,
  });
  final String id, name, reference, platform;
  final GameStyle style;
  final List<String> aliases;
  final bool verifyAvailability;
  List<GuideTopic> get topics => switch (style) {
    GameStyle.tactics || GameStyle.jobs => [
      GuideTopic.roster,
      GuideTopic.route,
      GuideTopic.missables,
    ],
    GameStyle.pokemon => [
      GuideTopic.party,
      GuideTopic.route,
      GuideTopic.missables,
    ],
    GameStyle.calendar => [
      GuideTopic.party,
      GuideTopic.missables,
      GuideTopic.route,
    ],
    GameStyle.standard => [
      GuideTopic.party,
      GuideTopic.route,
      GuideTopic.missables,
    ],
  };
  String get progressLabel =>
      style == GameStyle.calendar ? '현재 월' : '현재 챕터·진행 구간';
  List<String> get progressOptions => style == GameStyle.calendar
      ? List.generate(12, (i) => '${(i + 3) % 12 + 1}월')
      : const [];
  GameProfile profile({String? localId, String rules = ''}) =>
      GameProfile(id: localId ?? id, name: name, rules: rules, catalogId: id);
}

// A deliberately bounded, local directory. This is not the entire Switch library
// or a guide fact database. Official references are available in the picker;
// recommendations must still be grounded for the exact selected edition.
const gameCatalog = <GameDefinition>[
  GameDefinition(
    'fe-three-houses',
    '파이어 엠블렘 풍화설월',
    GameStyle.tactics,
    'https://www.nintendo.com/jp/switch/anvya/',
    aliases: ['파엠', 'fire emblem', 'three houses'],
  ),
  GameDefinition(
    'fe-engage',
    '파이어 엠블렘 인게이지',
    GameStyle.tactics,
    'https://www.nintendo.com/jp/switch/ayfna/',
    aliases: ['파엠', 'fire emblem', 'engage'],
  ),
  GameDefinition(
    'fe-fortunes-weave',
    '파이어 엠블렘 만자천홍',
    GameStyle.tactics,
    'https://www.nintendo.com/',
    platform: 'Nintendo Switch 2',
    verifyAvailability: true,
    aliases: ['파엠', 'fire emblem', 'fortunes weave'],
  ),
  GameDefinition(
    'pokemon-lets-go-pikachu',
    '포켓몬스터 레츠고! 피카츄',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/pika_vee/',
    aliases: ['포켓몬', 'pokemon', '레츠고'],
  ),
  GameDefinition(
    'pokemon-lets-go-eevee',
    '포켓몬스터 레츠고! 이브이',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/pika_vee/',
    aliases: ['포켓몬', 'pokemon', '레츠고'],
  ),
  GameDefinition(
    'pokemon-sword',
    '포켓몬스터 소드',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/sword_shield/',
    aliases: ['포켓몬', 'pokemon', '소드실드'],
  ),
  GameDefinition(
    'pokemon-shield',
    '포켓몬스터 실드',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/sword_shield/',
    aliases: ['포켓몬', 'pokemon', '소드실드'],
  ),
  GameDefinition(
    'pokemon-brilliant-diamond',
    '포켓몬스터 브릴리언트 다이아몬드',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/bdsp/',
    aliases: ['포켓몬', 'pokemon', '브다샤펄'],
  ),
  GameDefinition(
    'pokemon-shining-pearl',
    '포켓몬스터 샤이닝 펄',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/bdsp/',
    aliases: ['포켓몬', 'pokemon', '브다샤펄'],
  ),
  GameDefinition(
    'pokemon-arceus',
    'Pokémon LEGENDS 아르세우스',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/legends_arceus/',
    aliases: ['포켓몬', 'pokemon', '아르세우스'],
  ),
  GameDefinition(
    'pokemon-scarlet',
    '포켓몬스터 스칼렛',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/sv/',
    aliases: ['포켓몬', 'pokemon', '스바'],
  ),
  GameDefinition(
    'pokemon-violet',
    '포켓몬스터 바이올렛',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/sv/',
    aliases: ['포켓몬', 'pokemon', '스바'],
  ),
  GameDefinition(
    'pokemon-za',
    'Pokémon LEGENDS Z-A',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/legends_z-a/',
    aliases: ['포켓몬', 'pokemon', 'za', '레전즈'],
  ),
  GameDefinition(
    'pokemon-za-switch2',
    'Pokémon LEGENDS Z-A Nintendo Switch 2 Edition',
    GameStyle.pokemon,
    'https://www.pokemon.co.jp/ex/legends_z-a/',
    platform: 'Nintendo Switch 2',
    aliases: ['포켓몬', 'pokemon', 'za', '레전즈'],
  ),
  GameDefinition(
    'persona-3-portable',
    '페르소나 3 포터블',
    GameStyle.calendar,
    'https://p-ch.jp/remaster/',
    aliases: ['페르소나', 'persona', 'p3p'],
  ),
  GameDefinition(
    'persona-4-golden',
    '페르소나 4 골든',
    GameStyle.calendar,
    'https://p-ch.jp/remaster/',
    aliases: ['페르소나', 'persona', 'p4g'],
  ),
  GameDefinition(
    'persona-5-royal',
    '페르소나 5 더 로열',
    GameStyle.calendar,
    'https://p-ch.jp/remaster/',
    aliases: ['페르소나', 'persona', 'p5r', '로얄'],
  ),
  GameDefinition(
    'octopath-1',
    '옥토패스 트래블러',
    GameStyle.jobs,
    'https://www.jp.square-enix.com/octopathtraveler/',
    aliases: ['옥토패스', 'octopath', 'jrpg'],
  ),
  GameDefinition(
    'octopath-2',
    '옥토패스 트래블러 II',
    GameStyle.jobs,
    'https://www.jp.square-enix.com/octopathtraveler2/',
    aliases: ['옥토패스', '옥토패스2', 'octopath', 'jrpg'],
  ),
  GameDefinition(
    'bravely-default-2',
    '브레이블리 디폴트 II',
    GameStyle.jobs,
    'https://www.jp.square-enix.com/bd2/',
    aliases: ['브레이블리', 'bravely', 'jrpg'],
  ),
  GameDefinition(
    'dragon-quest-11s',
    '드래곤 퀘스트 XI S',
    GameStyle.standard,
    'https://www.dq11.jp/s/',
    aliases: ['드퀘', '드래곤퀘스트', 'dragon quest', 'jrpg'],
  ),
  GameDefinition(
    'smt-5-vengeance',
    '진 여신전생 V Vengeance',
    GameStyle.standard,
    'https://megaten5.jp/vengeance/',
    aliases: ['진여신전생', '벤전스', 'smt', 'jrpg'],
  ),
];

String normalizeGameQuery(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[\s!·:：\-]'), '');
List<GameDefinition> searchGames(String query) {
  final needle = normalizeGameQuery(query);
  return gameCatalog
      .where(
        (g) => [
          g.name,
          ...g.aliases,
        ].any((s) => normalizeGameQuery(s).contains(needle)),
      )
      .toList();
}

GameDefinition? definitionFor(GameProfile game) => gameCatalog
    .where(
      (g) =>
          g.id == game.catalogId ||
          normalizeGameQuery(g.name) == normalizeGameQuery(game.name),
    )
    .firstOrNull;
const genericGame = GameDefinition(
  'custom',
  '직접 추가한 게임',
  GameStyle.standard,
  '',
);
