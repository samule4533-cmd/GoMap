import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/saved_place.dart';
import '../../../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(),
);

final savedPlacesProvider = FutureProvider<List<SavedPlace>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return service.fetchMySavedPlaces();
});
