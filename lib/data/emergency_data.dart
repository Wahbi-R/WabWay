// ─── Embassy contact ──────────────────────────────────────────────────────────

class EmbassyContact {
  const EmbassyContact({
    required this.country,
    this.phone,
    this.address,
  });

  final String country;
  final String? phone;
  final String? address;

  Map<String, dynamic> toJson() => {
        'country': country,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
      };

  factory EmbassyContact.fromJson(Map<String, dynamic> j) => EmbassyContact(
        country: j['country'] as String? ?? '',
        phone: j['phone'] as String?,
        address: j['address'] as String?,
      );
}

// ─── Emergency info ───────────────────────────────────────────────────────────

class TripEmergencyInfo {
  const TripEmergencyInfo({
    required this.id,
    required this.tripId,
    this.insuranceProvider,
    this.insurancePolicyNum,
    this.insurancePhone,
    this.cardEmergencyPhone,
    this.localEmergencyNum,
    this.nearestHospital,
    this.embassyContacts = const [],
    this.notes,
  });

  final String id;
  final String tripId;
  final String? insuranceProvider;
  final String? insurancePolicyNum;
  final String? insurancePhone;
  final String? cardEmergencyPhone;
  final String? localEmergencyNum;
  final String? nearestHospital;
  final List<EmbassyContact> embassyContacts;
  final String? notes;

  bool get isEmpty =>
      insuranceProvider == null &&
      insurancePolicyNum == null &&
      insurancePhone == null &&
      cardEmergencyPhone == null &&
      localEmergencyNum == null &&
      nearestHospital == null &&
      embassyContacts.isEmpty &&
      notes == null;

  TripEmergencyInfo copyWith({
    String? insuranceProvider,
    String? insurancePolicyNum,
    String? insurancePhone,
    String? cardEmergencyPhone,
    String? localEmergencyNum,
    String? nearestHospital,
    List<EmbassyContact>? embassyContacts,
    String? notes,
  }) =>
      TripEmergencyInfo(
        id: id,
        tripId: tripId,
        insuranceProvider: insuranceProvider ?? this.insuranceProvider,
        insurancePolicyNum: insurancePolicyNum ?? this.insurancePolicyNum,
        insurancePhone: insurancePhone ?? this.insurancePhone,
        cardEmergencyPhone: cardEmergencyPhone ?? this.cardEmergencyPhone,
        localEmergencyNum: localEmergencyNum ?? this.localEmergencyNum,
        nearestHospital: nearestHospital ?? this.nearestHospital,
        embassyContacts: embassyContacts ?? this.embassyContacts,
        notes: notes ?? this.notes,
      );
}
