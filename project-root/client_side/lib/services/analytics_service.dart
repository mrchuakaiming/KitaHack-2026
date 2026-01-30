import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

// HOW TO USE?
/*
// In your view model or widget, when a user logs in:
await AnalyticsService().logLogin(method: 'email_password');

// When a user creates a room:
await AnalyticsService().logRoomCreated(roomId: 'abc123');

// On page open:
await AnalyticsService().logPageView(pageName: 'home_page');
*/

class AnalyticsService {
  // Singleton instance so we can access it anywhere
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Firebase Analytics instance
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Observer for navigation events (optional)
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Logs a generic event with optional parameters.
  /// name: the unique event name, e.g., 'login_success'
  /// params: a map of key-value pairs describing the event
  Future<void> logEvent(String name, {Map<String, dynamic>? params}) async {
    await _analytics.logEvent(name: name, parameters: params);
  }

  /// Logs a user login
  Future<void> logLogin({required String method}) async {
    await logEvent('login', params: {'method': method});
  }

  /// Logs when a user creates a room
  Future<void> logRoomCreated({required String roomId}) async {
    await logEvent('room_created', params: {'room_id': roomId});
  }

  /// Logs when a user views a page
  Future<void> logPageView({required String pageName}) async {
    await _analytics.logEvent('page_view', params: {'page': pageName});
  }

  /// Optional: sets the user ID for cross-device analytics
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// Optional: sets user properties for segmentation
  Future<void> setUserProperty({required String name, required String value}) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
}
