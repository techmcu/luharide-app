class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  String? get currentToken => null;

  Future<void> initialize() async {}
  Future<void> registerToken() async {}
  Future<void> unregisterToken() async {}
}
