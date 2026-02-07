/*
 * ====================================================================
 * COORDINATOR – REGISTER USER TEST
 * --------------------------------------------------------------------
 * UNIT TEST TARGET:
 * Coordinator.registerUser(...)
 *
 * Responsibilities under test:
 * - Creates Firebase Auth user
 * - Persists initial user profile in Firestore
 * - Returns enriched UserModel on success
 * - Rolls back Auth user and throws RegisterFailure if Firestore fails
 *
 * Firebase services are fully mocked.
 * ====================================================================
 */

// External Package
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Internal Package
import 'package:what2eat/coordinators/coordinator.dart';
import 'package:what2eat/models/user.dart';
import '../mocks/mocks.dart';

void main() {
  //Initialise later in setUp
  late MockAuthService mockAuth;
  late MockFirestoreService mockDb;
  late TestCoordinator coordinator;

  setUpAll(() {
    // Register fallback values for Mocktail any() / captureAny()
    registerCoordinatorFallbacks();
  });

  setUp(() {
    mockAuth = MockAuthService();
    mockDb = MockFirestoreService();

    // Use TestCoordinator to avoid real Firebase SDK calls.
    coordinator = TestCoordinator(
      auth: mockAuth,
      db: mockDb,
      rtdb: MockRTDBService(),
    );
  });

  test('registerUser success flow', () async {
    // Mock Firebase User & Credential
    final mockFirebaseUser = MockFirebaseUser();
    final mockCredential = MockUserCredential();

    when(() => mockFirebaseUser.uid).thenReturn('u1');
    when(() => mockFirebaseUser.email).thenReturn('a@test.com');
    when(() => mockCredential.user).thenReturn(mockFirebaseUser);

    // The user after Firestore persistence
    final fakeUserModel = UserModel(
      uid: 'u1',
      email: 'a@test.com',
      username: '',
      dietaryRestrictions: [],
      preferredCuisine: [],
      hostedRooms: [],
    );

    // AuthService.signUp
    // Pretends Firebase Auth successfully created the user
    when(() => mockAuth.signUp(any(), any()))
        .thenAnswer((_) async => mockCredential);

    // Firestore.replaceUser (called by updateProfile)
    when(() => mockDb.replaceUser(any())).thenAnswer((_) async {});

    // Firestore.getUser (called by getOrCreateUserModel)
    when(() => mockDb.getUser('u1')).thenAnswer((_) async => fakeUserModel);

    // Run registration flow
    final result = await coordinator.registerUser(
      email: 'a@test.com',
      password: '123456',
    );

    // Assert: The return is correct for UI
    expect(result.user.uid, 'u1');
    expect(result.user.email, 'a@test.com');

    // Verify correct calls
    verify(() => mockAuth.signUp('a@test.com', '123456')).called(1); // auth
    verify(() => mockDb.replaceUser(any())).called(1); // called by updateProfile
    verify(() => mockDb.getUser('u1')).called(1);      // called by getOrCreateUserModel
  });

  // If firestore fails
  test('registerUser deletes auth user if Firestore fails', () async {
    
    final mockFirebaseUser = MockFirebaseUser();
    final mockCredential = MockUserCredential();

    when(() => mockFirebaseUser.uid).thenReturn('u1');
    when(() => mockFirebaseUser.email).thenReturn('a@test.com');

    // Make sure user profile not saved in firestore (since not success)
    when(() => mockFirebaseUser.delete()).thenAnswer((_) async {}); 
    
    when(() => mockCredential.user).thenReturn(mockFirebaseUser);

    // AuthService.signUp (Success)
    when(() => mockAuth.signUp(any(), any()))
        .thenAnswer((_) async => mockCredential);

    // Firestore.replaceUser (Failure)
    when(() => mockDb.replaceUser(any())).thenThrow(Exception('Firestore Failed'));

    // Show Error
    await expectLater(
      () => coordinator.registerUser(email: 'a@test.com', password: '123456'),
      throwsA(isA<RegisterFailure>()),
    );

    // Verify signUp called
    verify(() => mockAuth.signUp('a@test.com', '123456')).called(1);

    // Verify replaceUser called
    verify(() => mockDb.replaceUser(any())).called(1);

    // Verify rollback: FirebaseUser.delete called
    verify(() => mockFirebaseUser.delete()).called(1);
  });
}