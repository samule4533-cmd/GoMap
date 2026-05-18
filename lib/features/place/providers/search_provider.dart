import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/naver_place.dart';
import '../../../services/naver_search_service.dart';

final naverSearchServiceProvider = Provider<NaverSearchService>(
  (ref) => NaverSearchService(),
);

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<NaverPlace>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final service = ref.read(naverSearchServiceProvider);
  return service.search(query);
});
