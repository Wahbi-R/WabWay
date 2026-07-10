import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/emergency_data.dart';
import 'client.dart';

abstract final class EmergencyService {
  static TripEmergencyInfo _fromRow(Map<String, dynamic> row) {
    final embassyRaw = row['embassy_contacts'] as List? ?? [];
    return TripEmergencyInfo(
      id: row['id'] as String,
      tripId: row['trip_id'] as String,
      insuranceProvider: row['insurance_provider'] as String?,
      insurancePolicyNum: row['insurance_policy_num'] as String?,
      insurancePhone: row['insurance_phone'] as String?,
      cardEmergencyPhone: row['card_emergency_phone'] as String?,
      localEmergencyNum: row['local_emergency_num'] as String?,
      nearestHospital: row['nearest_hospital'] as String?,
      embassyContacts: embassyRaw
          .cast<Map<String, dynamic>>()
          .map(EmbassyContact.fromJson)
          .toList(),
      notes: row['notes'] as String?,
    );
  }

  static Future<TripEmergencyInfo?> fetch(String tripId) async {
    final res = await supabase
        .from('trip_emergency_info')
        .select()
        .eq('trip_id', tripId)
        .maybeSingle();
    if (res == null) return null;
    return _fromRow(res);
  }

  static Future<TripEmergencyInfo> upsert(
    String tripId,
    TripEmergencyInfo info,
  ) async {
    final payload = {
      'trip_id': tripId,
      'insurance_provider': info.insuranceProvider,
      'insurance_policy_num': info.insurancePolicyNum,
      'insurance_phone': info.insurancePhone,
      'card_emergency_phone': info.cardEmergencyPhone,
      'local_emergency_num': info.localEmergencyNum,
      'nearest_hospital': info.nearestHospital,
      'embassy_contacts':
          info.embassyContacts.map((e) => e.toJson()).toList(),
      'notes': info.notes,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final res = await supabase
        .from('trip_emergency_info')
        .upsert(payload, onConflict: 'trip_id')
        .select()
        .single();
    return _fromRow(res);
  }
}
