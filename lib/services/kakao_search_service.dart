import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_keys.dart';
import '../models/kakao_place.dart';

class KakaoSearchService {
  Future<List<KakaoPlace>> searchByKeyword(
    String query, {
    double? lat,
    double? lng,
    int? radiusMeters,
    int size = 15,
  }) async {
    final params = <String, String>{'query': query, 'size': size.toString()};
    if (lat != null && lng != null) {
      params['x'] = lng.toString();
      params['y'] = lat.toString();
      params['sort'] = 'distance';
      if (radiusMeters != null) {
        params['radius'] = radiusMeters.toString();
      }
    }

    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/search/keyword.json',
      params,
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK ${ApiKeys.kakaoRestApiKey}'},
    );

    if (res.statusCode != 200) {
      throw Exception('Kakao search failed: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final documents = (body['documents'] as List).cast<Map<String, dynamic>>();
    return documents.map(KakaoPlace.fromJson).toList();
  }
}
