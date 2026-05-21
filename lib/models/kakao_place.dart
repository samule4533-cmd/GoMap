class KakaoPlace {
  final String id;
  final String title;
  final String? address;
  final String? roadAddress;
  final String? category;
  final String? telephone;
  final String? placeUrl;
  final double lat;
  final double lng;
  final int? distanceMeters;

  KakaoPlace({
    required this.id,
    required this.title,
    this.address,
    this.roadAddress,
    this.category,
    this.telephone,
    this.placeUrl,
    required this.lat,
    required this.lng,
    this.distanceMeters,
  });

  factory KakaoPlace.fromJson(Map<String, dynamic> json) {
    final distanceRaw = json['distance'] as String?;
    return KakaoPlace(
      id: json['id'] as String,
      title: json['place_name'] as String,
      address: (json['address_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['address_name'] as String,
      roadAddress:
          (json['road_address_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['road_address_name'] as String,
      category: (json['category_name'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['category_name'] as String,
      telephone: (json['phone'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['phone'] as String,
      placeUrl: (json['place_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['place_url'] as String,
      lng: double.parse(json['x'] as String),
      lat: double.parse(json['y'] as String),
      distanceMeters: distanceRaw == null || distanceRaw.isEmpty
          ? null
          : int.tryParse(distanceRaw),
    );
  }
}
