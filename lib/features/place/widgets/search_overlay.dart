import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/kakao_place.dart';
import '../providers/search_provider.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key, this.onPlaceTap});

  final void Function(KakaoPlace)? onPlaceTap;

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // 사용자가 검색바에 다시 포커스 → 리스트 복원
    if (_focusNode.hasFocus) {
      ref.read(searchListCollapsedProvider.notifier).state = false;
    }
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(searchListCollapsedProvider.notifier).state = false;
  }

  void _handleTap(KakaoPlace place) {
    widget.onPlaceTap?.call(place);
    ref.read(searchListCollapsedProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final listCollapsed = ref.watch(searchListCollapsedProvider);

    return Column(
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(28),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '장소 검색',
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clear,
                    ),
            ),
            onSubmitted: (value) {
              ref.read(searchListCollapsedProvider.notifier).state = false;
              ref.read(searchQueryProvider.notifier).state = value.trim();
            },
            onChanged: (_) {
              if (listCollapsed) {
                ref.read(searchListCollapsedProvider.notifier).state = false;
              }
              // suffixIcon(clear) 표시 토글 위해 강제 rebuild
              setState(() {});
            },
          ),
        ),
        if (!listCollapsed)
          results.when(
            data: (places) {
              if (places.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: places.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = places[i];
                        final subtitle = p.roadAddress ?? p.address;
                        return ListTile(
                          title: Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle != null
                              ? Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => _handleTap(p),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '검색 실패: $e',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
