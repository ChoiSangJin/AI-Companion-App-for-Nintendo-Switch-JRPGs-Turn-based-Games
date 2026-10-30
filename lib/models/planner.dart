class PokemonForm {
  PokemonForm.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      name = j['name'] as String,
      english = j['english'] as String,
      types = List<String>.from(j['types'] as List);
  final int id;
  final String name, english;
  final List<String> types;
}

class PokemonLine {
  PokemonLine.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      forms = (j['forms'] as List)
          .map((f) => PokemonForm.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
      conditions = List<String>.from(j['conditions'] as List),
      location = j['location'] as String,
      reason = j['reason'] as String,
      stage = j['stage'] as String,
      versions = List<String>.from(j['versions'] as List),
      starter = j['starter'] as bool,
      source = j['source'] as String;
  final String id, location, reason, stage, source;
  final List<PokemonForm> forms;
  final List<String> conditions, versions;
  final bool starter;
  String get name => forms.first.name;
  bool matches(String query) {
    final q = query.trim().toLowerCase().replaceAll(' ', '');
    return q.isEmpty ||
        forms.any(
          (f) => '${f.name}${f.english}${f.id}${f.types.join()}'
              .toLowerCase()
              .replaceAll(' ', '')
              .contains(q),
        );
  }
}

class RouteStop {
  RouteStop.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String,
      kind = j['kind'] as String,
      type = j['type'] as String,
      level = j['level'] as int,
      tip = j['tip'] as String,
      reward = j['reward'] as String;
  final String id, title, kind, type, tip, reward;
  final int level;
}

class PartyMember {
  PartyMember({
    required this.lineId,
    this.captured = false,
    this.evolution = 0,
    this.memo = '',
  });
  final String lineId;
  bool captured;
  int evolution;
  String memo;
  Map<String, dynamic> toJson() => {
    'lineId': lineId,
    'captured': captured,
    'evolution': evolution,
    'memo': memo,
  };
  factory PartyMember.fromJson(Map<String, dynamic> j) {
    final evolution = j['evolution'];
    if (evolution is! int || evolution < 0) {
      throw const FormatException('잘못된 육성 단계입니다.');
    }
    return PartyMember(
      lineId: j['lineId'] as String,
      captured: j['captured'] as bool,
      evolution: evolution,
      memo: j['memo'] as String? ?? '',
    );
  }
}

class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    this.memo = '',
    this.done = false,
    this.sourceId,
  });
  final String id;
  String title, memo;
  bool done;
  final String? sourceId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'memo': memo,
    'done': done,
    'sourceId': sourceId,
  };
  factory PlannerTask.fromJson(Map<String, dynamic> j) => PlannerTask(
    id: j['id'] as String,
    title: j['title'] as String,
    memo: j['memo'] as String? ?? '',
    done: j['done'] as bool,
    sourceId: j['sourceId'] as String?,
  );
}

class Adventure {
  Adventure({
    this.starter,
    List<PartyMember>? party,
    Set<String>? completed,
    List<PlannerTask>? tasks,
  }) : party = party ?? [],
       completed = completed ?? {},
       tasks = tasks ?? [];
  String? starter;
  final List<PartyMember> party;
  final Set<String> completed;
  final List<PlannerTask> tasks;
  Map<String, dynamic> toJson() => {
    'starter': starter,
    'party': party.map((m) => m.toJson()).toList(),
    'completed': completed.toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
  factory Adventure.fromJson(Map<String, dynamic> j) {
    final result = Adventure(
      starter: j['starter'] as String?,
      party: (j['party'] as List)
          .map((m) => PartyMember.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      completed: Set<String>.from(j['completed'] as List),
      tasks: (j['tasks'] as List)
          .map((t) => PlannerTask.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
    if (result.party.length > 6 ||
        result.party.map((m) => m.lineId).toSet().length !=
            result.party.length) {
      throw const FormatException('파티 기록을 확인할 수 없습니다.');
    }
    return result;
  }
}

class PlannerState {
  PlannerState({this.edition = 'scarlet', Map<String, Adventure>? adventures})
    : adventures =
          adventures ?? {'scarlet': Adventure(), 'violet': Adventure()};
  String edition;
  final Map<String, Adventure> adventures;
  Adventure get current => adventures[edition]!;
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'edition': edition,
    'adventures': adventures.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory PlannerState.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 1 ||
        !const ['scarlet', 'violet'].contains(j['edition'])) {
      throw const FormatException('지원하지 않는 기록 형식입니다.');
    }
    final entries = j['adventures'] as Map;
    return PlannerState(
      edition: j['edition'] as String,
      adventures: {
        for (final id in ['scarlet', 'violet'])
          id: Adventure.fromJson(Map<String, dynamic>.from(entries[id] as Map)),
      },
    );
  }
  PlannerState copy() => PlannerState.fromJson(toJson());
}
