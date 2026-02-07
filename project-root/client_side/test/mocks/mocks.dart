/*
 * ====================================================================
 * UPDATED TEST MOCKS
 * --------------------------------------------------------------------
 * Fixed 'QueryDocumentSnapshot' sealed class error.
 * Added missing service mocks to match Coordinator dependencies.
 * ====================================================================
 */
//External package
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

//Internal package
import 'package:what2eat/coordinators/coordinator.dart';
import 'package:what2eat/services/auth_service.dart';
import 'package:what2eat/services/firestore_service.dart';
import 'package:what2eat/services/rtdb_services.dart';
import 'package:what2eat/services/maps_service.dart';
import 'package:what2eat/services/ai_service.dart';
import 'package:what2eat/models/user.dart';

/// not calling the real service
/// =======================
/// MOCK SERVICES
/// =======================
class MockAuthService extends Mock implements AuthService {}
class MockFirestoreService extends Mock implements FirestoreService {}
class MockRTDBService extends Mock implements RTDBService {}
class MockMapsService extends Mock implements MapsService {}
class MockAIService extends Mock implements AIService {}

/// =======================
/// MOCK FIREBASE MODELS
/// =======================
class MockFirebaseUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}

/// =======================
/// FAKES (For Mocktail)
/// =======================
class FakeUserModel extends Fake implements UserModel {}
class FakeUser extends Fake implements User {}

/// =======================
/// TEST COORDINATOR
/// =======================
/// This class is essential because it prevents the real Coordinator 
/// from calling FirebaseFirestore.instance 
/// (which crashes unit tests without calling real services).
class TestCoordinator extends Coordinator {
  // 1. Add this field to store a manual ID for testing
  String? manualRoomId;

  TestCoordinator({
    super.auth, 
    super.db, 
    super.rtdb,
    super.maps,
    super.ai,
  });

  // 2. Override generateRoomId to return the manual ID if set
  @override
  Future<String> generateRoomId() async {
    return manualRoomId ?? 'default_room_id';
  }

  @override
  Future<List<String>> getHostedRoomIds({required String hostUid}) async {
    return ['room_abc', 'room_xyz'];
  }
}

/// =======================
/// FALLBACK REGISTRY
/// =======================
void registerCoordinatorFallbacks() {
  // Add this line if it's not there!
  registerFallbackValue(<String, dynamic>{}); 
  
  // Also register your UserModel if you use it in any() matchers
  registerFallbackValue(UserModel(
    uid: '', email: '', username: '', 
    dietaryRestrictions: [], preferredCuisine: [], hostedRooms: []
  ));
  registerFallbackValue(''); // Fallback for String any()
}