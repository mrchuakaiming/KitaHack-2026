/*
 * ====================================================================
 * COORDINATOR – LOG IN TEST
 * --------------------------------------------------------------------
 * UNIT TEST TARGET:
 *   Coordinator.logIn(...)
 *
 * Responsibilities:
 *  - Returns UserCredential and enriched UserModel
 *  - Uses AuthService + FirestoreService
 *
 * Firebase services are fully mocked.
 * ====================================================================
 */

//External package
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//Internal package
import 'package:what2eat/models/user.dart';
import '../mocks/mocks.dart';

void main() {
  //initialised in setUp
  late MockAuthService mockAuth;
  late MockFirestoreService mockDb;
  late TestCoordinator coordinator; // Use the wrapper
  late MockUserCredential mockCredential;
  late MockFirebaseUser mockUser;

  setUpAll(() {
    registerCoordinatorFallbacks();
  });

  setUp(() {
    mockAuth = MockAuthService();
    mockDb = MockFirestoreService();
    mockCredential = MockUserCredential();
    mockUser = MockFirebaseUser();

    //initialise TestCoordinator to prevent firebase calls
    coordinator = TestCoordinator(
      auth: mockAuth,
      db: mockDb,
      rtdb: MockRTDBService(),
    );

    // Stub the Firebase UserCredential and User objects
    when(() => mockCredential.user).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');
    when(() => mockUser.email).thenReturn('a@test.com');
  });

  // Check logIn returns credential and enriched user model
  test('logIn returns credential and enriched user', () async {
    // define a fake userModel if come from firestore
    final userFromDb = UserModel(
      uid: 'u1',
      email: 'a@test.com',
      username: 'Alice',
      dietaryRestrictions: [],
      preferredCuisine: [],
      hostedRooms: [], 
    );

    // Simulates successful login without real Firebase
    when(() => mockAuth.signIn('a@test.com', '123456'))
        .thenAnswer((_) async => mockCredential);
    // Simulates fetching the enriched user from Firestore after login.
    when(() => mockDb.getUser('u1')).thenAnswer((_) async => userFromDb);

    // Call the method to test
    final result = await coordinator.logIn(
      email: 'a@test.com',
      password: '123456',
    );

    // Assert: should return an object containing
    expect(result.credential, mockCredential); // Firebase UserCredential
    expect(result.user.username, 'Alice'); // UserModel
    
    // Confirms the TestCoordinator override worked for getHostedRoomIds
    expect(result.user.hostedRooms, contains('room_abc'));

    // Verify: signIn was called exactly once
    verify(() => mockAuth.signIn('a@test.com', '123456')).called(1);
    // Verify: getUser was called exactly once
    verify(() => mockDb.getUser('u1')).called(1);
  });

  test('logIn fails when AuthService throws', () async {
  // Arrange: simulate Firebase Auth throwing an exception (wrong password, network error, etc.)
  when(() => mockAuth.signIn('a@test.com', 'wrongpass'))
      .thenThrow(Exception('Auth failed'));

  // Call and Assert: logIn should throw
  await expectLater(
    () => coordinator.logIn(
      email: 'a@test.com',
      password: 'wrongpass',
    ),
    throwsA(isA<Exception>()),
  );

  // Verify: signIn was attempted exactly once
  verify(() => mockAuth.signIn('a@test.com', 'wrongpass')).called(1);

  // Verify: getUser should never be called because login failed
  verifyNever(() => mockDb.getUser(any()));
});

}