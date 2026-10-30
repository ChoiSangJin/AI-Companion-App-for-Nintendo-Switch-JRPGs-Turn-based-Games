import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gemini_models.dart';

typedef SaveAiSettings = Future<void> Function(String key, String model);

class AiSetupPage extends StatefulWidget {
  const AiSetupPage({
    super.key,
    required this.initialKey,
    required this.initialModel,
    required this.onSave,
    this.service,
    this.openLink,
  });
  final String initialKey, initialModel;
  final SaveAiSettings onSave;
  final GeminiModelsService? service;
  final Future<bool> Function(Uri)? openLink;
  @override
  State<AiSetupPage> createState() => _AiSetupPageState();
}

class _AiSetupPageState extends State<AiSetupPage> {
  late final keyInput = TextEditingController(text: widget.initialKey);
  late final service = widget.service ?? GeminiModelsService();
  GeminiModelList? catalog;
  String selected = '', listedKey = '', notice = '';
  String verifiedKey = '', verifiedModel = '';
  bool get verified => verifiedKey == listedKey && verifiedModel == selected;
  String? error;
  bool visible = false, fetching = false, saving = false, testing = false;
  int generation = 0;
  bool get busy => fetching || saving || testing;
  bool get canSave =>
      !busy &&
      listedKey == keyInput.text.trim() &&
      catalog != null &&
      catalog!.models.any((m) => m.id == selected);
  @override
  void initState() {
    super.initState();
    selected = widget.initialModel;
    keyInput.addListener(_keyChanged);
    if (widget.initialKey.trim().isNotEmpty) _loadModels();
  }

  void _keyChanged() {
    if (keyInput.text.trim() == listedKey && listedKey.isNotEmpty) return;
    generation++;
    setState(() {
      verifiedKey = verifiedModel = '';
      catalog = null;
      listedKey = '';
      notice = '';
      error = null;
      fetching = false;
      testing = false;
    });
  }

  @override
  void dispose() {
    generation++;
    keyInput.dispose();
    if (widget.service == null) service.close();
    super.dispose();
  }

  void _announceError() {
    if (mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error!)));
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      final ok =
          await (widget.openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('브라우저를 열 수 없습니다. 표시된 주소를 브라우저에 입력해 주세요.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('브라우저를 열지 못했습니다. 공식 안내 주소를 확인해 주세요.')),
        );
      }
    }
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (data?.text == null || data!.text!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('복사한 키가 없습니다. AI Studio에서 API 키를 복사해 주세요.'),
          ),
        );
        return;
      }
      keyInput.text = data.text!.trim();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('붙여넣지 못했습니다. 입력칸을 길게 눌러 붙여넣어 주세요.')),
        );
      }
    }
  }

  Future<void> _loadModels() async {
    if (saving || testing) return;
    final key = keyInput.text.trim();
    final request = ++generation;
    verifiedKey = verifiedModel = '';
    final previousSelection = selected;
    final keepSelection =
        key == listedKey ||
        (widget.initialKey.trim().isNotEmpty &&
            key == widget.initialKey.trim());
    setState(() {
      fetching = true;
      error = null;
      notice = '';
    });
    try {
      final result = await service.listModels(key);
      if (!mounted || request != generation || keyInput.text.trim() != key) {
        return;
      }
      setState(() {
        catalog = result;
        listedKey = key;
        selected =
            keepSelection && result.models.any((m) => m.id == previousSelection)
            ? previousSelection
            : result.connectionCandidate!.id;
        notice =
            '모델 목록만 확인했습니다. 무료 사용 가능 여부는 아직 확인되지 않았습니다. 저장할 때 선택한 모델로 검색 연결을 확인합니다.';
      });
    } on FormatException catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e.message;
          catalog = null;
          listedKey = '';
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          error = '공식 모델 목록을 불러오지 못했습니다. 다시 시도해 주세요.';
          catalog = null;
          listedKey = '';
        });
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => fetching = false);
        if (error != null) _announceError();
      }
    }
  }

  Future<void> _testSearch() async {
    if (!canSave) return;
    verifiedKey = verifiedModel = '';
    final key = listedKey, model = selected, request = ++generation;
    setState(() {
      testing = true;
      error = null;
      notice = '';
    });
    try {
      await service.testSearch(key, model);
      if (mounted && request == generation && model == selected) {
        setState(() {
          verifiedKey = key;
          verifiedModel = model;
          notice = '검색 연결을 확인했습니다. 현재 요청이 성공했다는 뜻이며 무료 요금이나 남은 한도를 보장하지 않습니다.';
        });
      }
    } on FormatException catch (e) {
      if (mounted && request == generation) setState(() => error = e.message);
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = '검색 연결을 확인하지 못했습니다. 다른 모델을 선택하거나 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => testing = false);
        if (error != null) _announceError();
      }
    }
  }

  Future<void> _save() async {
    if (!canSave) return;
    if (!verified) await _testSearch();
    if (!mounted || !canSave || !verified) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(keyInput.text.trim(), selected);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => error = '연결 정보를 저장하지 못했습니다. 기기 저장 공간과 잠금 설정을 확인해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
        if (error != null) _announceError();
      }
    }
  }

  Future<void> _remove() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('저장한 API 키를 삭제할까요?'),
            content: const Text(
              '기기에 저장한 목표와 공략은 유지됩니다. 새 AI 검색을 하려면 키를 다시 연결해야 합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('키 삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    generation++;
    setState(() {
      saving = true;
      fetching = false;
      testing = false;
      error = null;
    });
    try {
      await widget.onSave('', widget.initialModel);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => error = 'API 키를 삭제하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => saving = false);
        if (error != null) _announceError();
      }
    }
  }

  Widget _step(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _model(GeminiModel model) => RadioListTile<String>(
    value: model.id,
    enabled: !busy,
    title: Text(
      '${model.name}${verified && selected == model.id ? ' · 검색 연결 확인' : ''}',
    ),
    subtitle: Text(
      '${model.kind}${model.preview
          ? ' · 미리보기/실험용'
          : model.alias
          ? ' · 자동 변경 별칭'
          : ''}\n${model.id}',
    ),
    isThreeLine: true,
    contentPadding: EdgeInsets.zero,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 연결 안내')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('개발 지식 없이 Google 계정으로 시작할 수 있어요. 아래 순서대로 진행해 주세요.'),
          const SizedBox(height: 12),
          _step('1. Google에서 API 키 만들기', [
            const Text(
              '① Google 계정으로 로그인합니다.\n② 이용 약관을 확인하고 ‘API 키 만들기(Create API key)’를 선택합니다.\n③ 프로젝트 선택 화면이 나오면 Google 안내에 따라 프로젝트를 선택하거나 만듭니다.\n④ 만들어진 키 값을 복사한 뒤 이 앱으로 돌아옵니다.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _open(GeminiLinks.apiKeys),
              icon: const Icon(Icons.open_in_new),
              label: const Text('AI Studio에서 API 키 만들기'),
            ),
            const SizedBox(height: 8),
            const SelectableText('https://aistudio.google.com/apikey'),
            TextButton(
              onPressed: () => _open(GeminiLinks.keyHelp),
              child: const Text('버튼을 찾기 어려우면 공식 발급 안내 보기'),
            ),
          ]),
          _step('2. 복사한 키 붙여넣기', [
            TextField(
              key: const ValueKey('api-key-input'),
              controller: keyInput,
              enabled: !saving,
              obscureText: !visible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: '내 API 키',
                hintText: 'Google에서 복사한 키 값',
                suffixIcon: IconButton(
                  tooltip: visible ? '키 숨기기' : '키 보기',
                  onPressed: () => setState(() => visible = !visible),
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: saving ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('복사한 키 붙여넣기'),
            ),
            const Text('키는 비밀번호처럼 다른 사람에게 공유하지 마세요. 이 기기의 보안 저장소에 저장합니다.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _loadModels,
              icon: const Icon(Icons.sync),
              label: const Text('키 확인하고 공식 모델 불러오기'),
            ),
          ]),
          if (fetching || testing || saving) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (notice.isNotEmpty)
            Padding(padding: const EdgeInsets.all(12), child: Text(notice)),
          _step('3. 모델 선택 및 연결 확인', [
            if (catalog == null) ...[
              const Text(
                '키를 확인하면 Google 공식 API의 모델 목록을 최신 버전부터 표시합니다. 모델 이름을 직접 입력할 필요가 없어요.',
              ),
              if (widget.initialKey.isNotEmpty)
                Text('현재 저장된 모델: ${widget.initialModel}'),
            ] else ...[
              const Text(
                '목록은 최신 버전순이며 무료 모델 목록이 아닙니다. 처음에는 안정 Flash를 연결 후보로 선택합니다. 목록에 보여도 무료 할당량이 0일 수 있습니다. 실패하면 다른 Flash를 선택해 확인하세요.',
              ),
              if (catalog!.connectionCandidate != null &&
                  selected != catalog!.connectionCandidate!.id)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          selected = catalog!.connectionCandidate!.id;
                          error = null;
                          notice = '';
                        }),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    '최신 Flash 후보 선택: ${catalog!.connectionCandidate!.name}',
                  ),
                ),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null && !busy) {
                    setState(() {
                      selected = value;
                      error = null;
                      notice = '';
                    });
                  }
                },
                child: Column(
                  children: [
                    ...catalog!.stable.map(_model),
                    if (catalog!.additional.isNotEmpty)
                      ExpansionTile(
                        title: const Text('미리보기·추가 모델'),
                        initiallyExpanded: catalog!.additional.any(
                          (m) => m.id == selected,
                        ),
                        subtitle: const Text(
                          '변경·중단 가능성이 있어요. 자동 변경 별칭도 여기에 표시합니다.',
                        ),
                        children: catalog!.additional.map(_model).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: canSave ? _testSearch : null,
                icon: const Icon(Icons.search),
                label: const Text('선택 모델로 검색 연결 테스트'),
              ),
              const Text(
                '저장 전 검색 연결 확인이 필요합니다. 저장 버튼도 같은 테스트를 실행합니다. 공개 질문 1회로 사용량이 소모되며, 결제가 연결된 프로젝트는 요금이 발생할 수 있습니다. 무료 제공 여부를 보장하는 검사는 아닙니다.',
              ),
            ],
            TextButton(
              onPressed: () => _open(GeminiLinks.usage),
              child: const Text('AI Studio에서 내 사용량·한도 확인'),
            ),
            TextButton(
              onPressed: () => _open(GeminiLinks.models),
              child: const Text('Google 공식 모델·지원 기능 안내'),
            ),
          ]),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '새 공략을 요청할 때 검색어·게임 이름·규칙과 붙여넣은 공략이 Google로 전송됩니다. 저장한 목표·공략을 오프라인에서 읽는 데에는 API 키가 필요하지 않습니다.',
            ),
          ),
          const Text(
            '무료 할당량과 요금은 계정·모델에 따라 다릅니다. Gemini 앱 구독과 API 이용 요금은 별도입니다.',
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: () => _open(GeminiLinks.pricing),
                child: const Text('공식 요금 안내'),
              ),
              TextButton(
                onPressed: () => _open(GeminiLinks.regions),
                child: const Text('계정·지역 이용 조건'),
              ),
            ],
          ),
          if (widget.initialKey.isNotEmpty)
            TextButton(
              onPressed: busy ? null : _remove,
              child: const Text('저장한 API 키 삭제'),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (catalog != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '선택: ${catalog!.models.where((m) => m.id == selected).firstOrNull?.name ?? selected}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('이 설정으로 저장'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
