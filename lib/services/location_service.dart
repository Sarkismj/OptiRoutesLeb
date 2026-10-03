import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getLocations() async {
    final data = await supabase
        .from('locations')
        .select();

    return List<Map<String, dynamic>>.from(data);
  }
}