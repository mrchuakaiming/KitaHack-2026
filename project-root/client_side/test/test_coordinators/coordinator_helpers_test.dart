/*
 * ====================================================================
 * coordinator_helpers_test.dart
 * --------------------------------------------------------------------
 * UNIT TEST TARGET:
 * Coordinator.getOrCreateUserModel(...)
 *
 * TEST COVERAGE:
 * 1) Returns existing Firestore user when found
 * 2) Creates and persists a default user when missing
 *
 * TEST TYPE:
 * Pure unit test (uses TestCoordinator to bypass singleton errors)
 * ====================================================================
 */

// External package
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Internal package
import 'package:what2eat/models/user.dart';
import '../mocks/mocks.dart';

void main() {
  // initialised later in setUp
  late MockFirestoreService mockDb;
  late TestCoordinator coordinator;

  setUpAll(() {
    // Register fallback values so mocktail can handle any<UserModel>()
    registerCoordinatorFallbacks();
  });

  setUp(() {
    mockDb = MockFirestoreService();

    // Use TestCoordinator to prevent real Firebase calls.
    coordinator = TestCoordinator(
      db: mockDb,
      auth: MockAuthService(),
      rtdb: MockRTDBService(),
      maps: MockMapsService(),
      ai: MockAIService(),
    );

    // Default stub for replaceUser to prevent "Null is not a subtype of Future" error.
    // This ensures that any call to replaceUser returns a valid Future.
    when(() => mockDb.replaceUser(any())).thenAnswer((_) async {});
  });

  group('getOrCreateUserModel', () {
    //the coordinator returns the existing Firestore user if it exists
    test('returns existing user if found', () async {
      // Prepare a fake user object
      final existingUser = UserModel(
        uid: 'u1',
        email: 'alice@test.com',
        username: 'Alice',
        dietaryRestrictions: [],
        preferredCuisine: [],
        hostedRooms: [],
      );

      // Stub the DB read to return the user
      when(() => mockDb.getUser('u1')).thenAnswer((_) async => existingUser);

      // Test getOrCreateUserModel
      final result = await coordinator.getOrCreateUserModel(
        uid: 'u1',
        email: 'alice@test.com',
      );

      // Assert: checks the returned user has the correct uid and username
      expect(result.uid, 'u1');
      expect(result.username, 'Alice');

      // Verify: only checked / call the DB 1 time
      verify(() => mockDb.getUser('u1')).called(1);
      
      // Verify: did not overwrite existing data
      verifyNever(() => mockDb.replaceUser(any()));
    });

    // when the user does not exist in Firestore
    test('creates default user if missing', () async {
      // Arrange
      // 1. Stub getUser to return null (simulate user not in database)
      when(() => mockDb.getUser('u1')).thenAnswer((_) async => null);

      // 2. Stub replaceUser to return a completed Future (prevents the crash)
      when(() => mockDb.replaceUser(any())).thenAnswer((_) async {});

      // Test getOrCreateUserModel
      final result = await coordinator.getOrCreateUserModel(
        uid: 'u1',
        email: 'new@test.com',
      );

      // Assert: correct ...
      expect(result.uid, 'u1'); //uid
      expect(result.email, 'new@test.com'); //email
      expect(result.username, ''); // Default username (empty before updateProfile)

      // Verify: only checked / call the DB 1 time
      verify(() => mockDb.getUser('u1')).called(1);

      // Verify: only checked / call the DB 1 time to persist new user
      verify(() => mockDb.replaceUser(any())).called(1);
    });
  });
}