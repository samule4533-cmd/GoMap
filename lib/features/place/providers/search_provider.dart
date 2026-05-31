import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/kakao_place.dart';
import '../../../services/kakao_search_service.dart';
import '../../../services/location_service.dart';

final kakaoSearchServiceProvider = Provider<KakaoSearchService>(
  (ref) => KakaoSearchService(),
);

/// 현재 좌표. 첫 호출 시 위치를 받아 캐싱하고 이후 검색에서 재사용.
/// 권한 거부/타임아웃이면 null. 수동 갱신은 `ref.invalidate(currentLocationProvider)`.
final currentLocationProvider = FutureProvider<({double lat, double lng})?>(
  (ref) => LocationService.getCurrentPosition(),
);

final searchQueryProvider = StateProvider<String>((ref) => '');

/// 결과 리스트를 접었는지 여부. 검색어/캐시는 유지하고 리스트만 숨긴다.
/// - 결과 탭 / 외부(지도) 탭 → true
/// - 검색바 재포커스 / 검색어 변경 → false
final searchListCollapsedProvider = StateProvider<bool>((ref) => false);

final searchResultsProvider = FutureProvider<List<KakaoPlace>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final service = ref.read(kakaoSearchServiceProvider);
  final coord = await ref.watch(currentLocationProvider.future);
  return service.searchByKeyword(query, lat: coord?.lat, lng: coord?.lng);
});
