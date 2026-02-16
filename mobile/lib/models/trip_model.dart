class TripModel {
  final String id;
  final String fromLocation;
  final String toLocation;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final double farePerSeat;
  final int availableSeats;
  final int totalSeats;
  final String? vehicleNumber;
  final String? vehicleModelId;
  final List<String> stops;
  final String status;
  final DriverInfo? driver;
  final int pendingRequestsCount; // For driver: how many need approval

  TripModel({
    required this.id,
    required this.fromLocation,
    required this.toLocation,
    required this.departureTime,
    this.arrivalTime,
    required this.farePerSeat,
    required this.availableSeats,
    required this.totalSeats,
    this.vehicleNumber,
    this.vehicleModelId,
    this.stops = const [],
    required this.status,
    this.driver,
    this.pendingRequestsCount = 0,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id']?.toString() ?? '',
      fromLocation: json['from_location']?.toString() ?? '',
      toLocation: json['to_location']?.toString() ?? '',
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'])
          : DateTime.now(),
      arrivalTime: json['arrival_time'] != null
          ? DateTime.tryParse(json['arrival_time'])
          : null,
      farePerSeat: double.tryParse(json['fare_per_seat']?.toString() ?? '0') ?? 0.0,
      availableSeats: int.tryParse(json['available_seats']?.toString() ?? '0') ?? 0,
      totalSeats: int.tryParse(json['total_seats']?.toString() ?? '0') ?? 0,
      vehicleNumber: json['vehicle_number']?.toString(),
      vehicleModelId: json['vehicle_model_id']?.toString(),
      stops: json['stops'] != null
          ? (json['stops'] is List
              ? List<String>.from(json['stops'])
              : [])
          : [],
      status: json['status']?.toString() ?? 'scheduled',
      driver: json['driver'] != null
          ? DriverInfo.fromJson(json['driver'])
          : null,
      pendingRequestsCount: int.tryParse(json['pending_requests_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_location': fromLocation,
      'to_location': toLocation,
      'departure_time': departureTime.toIso8601String(),
      'arrival_time': arrivalTime?.toIso8601String(),
      'fare_per_seat': farePerSeat,
      'available_seats': availableSeats,
      'total_seats': totalSeats,
      'vehicle_number': vehicleNumber,
      'vehicle_model_id': vehicleModelId,
      'stops': stops,
      'status': status,
      'driver': driver?.toJson(),
    };
  }

  String get formattedDepartureTime {
    final hour = departureTime.hour;
    final minute = departureTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${departureTime.day} ${months[departureTime.month - 1]}, ${departureTime.year}';
  }

  Duration? get estimatedDuration {
    if (arrivalTime != null) {
      return arrivalTime!.difference(departureTime);
    }
    return null;
  }

  String get formattedDuration {
    final duration = estimatedDuration;
    if (duration == null) return 'N/A';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class DriverInfo {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? whatsappNumber;
  final bool isVerified;

  DriverInfo({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.whatsappNumber,
    this.isVerified = false,
  });

  /// For WhatsApp / contact – prefer WhatsApp number, fallback to phone
  String? get contactNumber =>
      (whatsappNumber != null && whatsappNumber!.trim().isNotEmpty)
          ? whatsappNumber
          : phone;

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Driver',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      whatsappNumber: json['whatsapp_number']?.toString(),
      isVerified: json['isVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'whatsapp_number': whatsappNumber,
      'isVerified': isVerified,
    };
  }
}
