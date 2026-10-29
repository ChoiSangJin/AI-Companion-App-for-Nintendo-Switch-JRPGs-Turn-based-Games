import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/models.dart';

// Preserve Google's supplied search suggestions. Remote navigation always opens
// in the browser; scripts and arbitrary in-app navigation remain disabled.
class SearchSuggestion extends StatefulWidget {
  const SearchSuggestion({super.key, required this.html});
  final String html;
  @override
  State<SearchSuggestion> createState() => _SearchSuggestionState();
}

class _SearchSuggestionState extends State<SearchSuggestion> {
  late final WebViewController controller;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri != null && uri.scheme == 'https' && request.isMainFrame) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                /* Browser may be unavailable. */
              }
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(widget.html);
  }

  @override
  void didUpdateWidget(SearchSuggestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) controller.loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 180, child: WebViewWidget(controller: controller));
}

class GuideSources extends StatelessWidget {
  const GuideSources({super.key, required this.guide});
  final GuideData guide;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (guide.sources.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('검색 출처 · 추천 조건을 확인하세요'),
        ),
      ...guide.sources.map(
        (source) => TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(source['title'] ?? '출처'),
          onPressed: () async {
            final uri = Uri.tryParse(source['uri'] ?? '');
            if (uri == null || uri.scheme != 'https') return;
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('출처를 열 수 없습니다.')));
              }
            }
          },
        ),
      ),
      if (guide.searchEntryPoint.isNotEmpty)
        SearchSuggestion(html: guide.searchEntryPoint),
    ],
  );
}
