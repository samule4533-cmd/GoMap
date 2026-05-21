class Place {
  final String id;
  final String provider;
  final String providerKey;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String? category;

  Place({
    required this.id,
    required this.provider,
    required this.providerKey,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    this.category,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    provider: json['provider'] as String,
    providerKey: json['provider_key'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    category: json['category'] as String?,
  );
}
