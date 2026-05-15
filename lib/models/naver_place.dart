import '../core/utils/coord_converter.dart';

class NaverPlace {
  final String title;
  final String? address;
  final String? roadAddress;
  final String? category;
  final String? telephone;
  final double lat;
  final double lng;

  NaverPlace({
    required this.title,
    this.address,
    this.roadAddress,
    this.category,
    this.telephone,
    required this.lat,
    required this.lng,
  });

  factory NaverPlace.fromJson(Map<String, dynamic> json) => NaverPlace(
        title: (json['title'] as String).replaceAll(RegExp(r'<[^>]*>'), ''),
        address: json['address'] as String?,
        roadAddress: json['roadAddress'] as String?,
        category: json['category'] as String?,
        telephone: json['telephone'] as String?,
        lat: CoordConverter.naverMapYToLat(json['mapy'].toString()),
        lng: CoordConverter.naverMapXToLng(json['mapx'].toString()),
      );
}
