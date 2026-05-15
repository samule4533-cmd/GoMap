import 'place.dart';
import 'place_visibility.dart';

class SavedPlace {
  final String id;
  final String userId;
  final String placeId;
  final String? memo;
  final PlaceVisibility visibility;
  final DateTime createdAt;
  final Place? place;

  SavedPlace({
    required this.id,
    required this.userId,
    required this.placeId,
    this.memo,
    required this.visibility,
    required this.createdAt,
    this.place,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        placeId: json['place_id'] as String,
        memo: json['memo'] as String?,
        visibility: PlaceVisibility.fromDb(json['visibility'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        place: json['place'] is Map<String, dynamic>
            ? Place.fromJson(json['place'] as Map<String, dynamic>)
            : null,
      );
}
