import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_keys.dart';
import '../models/naver_place.dart';

class NaverSearchService {
  Future<List<NaverPlace>> search(String query, {int display = 10}) async {
    final uri = Uri.https('openapi.naver.com', '/v1/search/local.json', {
      'query': query,
      'display': display.toString(),
    });
    final res = await http.get(
      uri,
      headers: {
        'X-Naver-Client-Id': ApiKeys.naverClientId,
        'X-Naver-Client-Secret': ApiKeys.naverClientSecret,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Naver search failed: ${res.statusCode}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    return items.map(NaverPlace.fromJson).toList();
  }
}
