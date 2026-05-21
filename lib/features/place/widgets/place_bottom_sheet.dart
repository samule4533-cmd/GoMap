import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/kakao_place.dart';

class PlaceBottomSheet extends StatelessWidget {
  const PlaceBottomSheet({super.key, required this.place});

  final KakaoPlace place;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _openInNaverMap() async {
    // 네이버 지도는 title 단독 검색이 정확함.
    // 주소를 같이 붙이면 "그 정확한 문자열"을 찾으려고 해서 매칭 실패.
    final encoded = Uri.encodeComponent(place.title);

    final appUri = Uri.parse(
      'nmap://search?query=$encoded&appname=com.gomap.gomap',
    );
    final webUri = Uri.parse('https://map.naver.com/p/search/$encoded');

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = place.roadAddress ?? place.address;
    final phone = place.telephone;
    final hasPhone = phone != null && phone.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.title, style: theme.textTheme.titleLarge),
            if (place.category != null) ...[
              const SizedBox(height: 4),
              Text(
                place.category!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(subtitle)),
                ],
              ),
            ],
            if (hasPhone) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _call(phone),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.call_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openInNaverMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('네이버 지도에서 보기'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Supabase 셋업 후 활성화
                onPressed: null,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
