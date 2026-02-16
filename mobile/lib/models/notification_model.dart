/// Immutable DTO for API notification.
/// OOP: value object with fromJson, copyWith, equality for consistency.
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String? message;
  final bool isRead;
  final DateTime? createdAt;
  /// Optional payload e.g. { "booking_id": "..." } for rate_ride
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.message,
    required this.isRead,
    this.createdAt,
    this.data,
  });

  String? get bookingId => data != null ? data!['booking_id']?.toString() : null;

  NotificationModel copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          id == other.id &&
          type == other.type &&
          isRead == other.isRead;

  @override
  int get hashCode => Object.hash(id, type, isRead);

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? dataMap;
    if (json['data'] != null) {
      if (json['data'] is Map) {
        dataMap = Map<String, dynamic>.from(json['data'] as Map);
      }
    }
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: (json['message'] ?? json['body'])?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      data: dataMap,
    );
  }
}

