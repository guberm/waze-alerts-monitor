class AlertModel {
  final String type;
  final String? subtype;
  final String street;
  final String city;
  final String? severity;
  final double? latitude;
  final double? longitude;

  AlertModel({
    required this.type,
    this.subtype,
    required this.street,
    required this.city,
    this.severity,
    this.latitude,
    this.longitude,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      type: json['type'] ?? 'UNKNOWN',
      subtype: json['subtype'],
      street: json['street'] ?? 'Unknown street',
      city: json['city'] ?? 'Unknown city',
      severity: json['severity'],
      latitude: json['location']?['y'] as double?,
      longitude: json['location']?['x'] as double?,
    );
  }
}