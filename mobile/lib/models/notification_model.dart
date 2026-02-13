class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String? message;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.message,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: (json['message'] ?? json['body'])?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

