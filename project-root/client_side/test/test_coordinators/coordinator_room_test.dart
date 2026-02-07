/*
 * ====================================================================
 * coordinator_room_test.dart
 * --------------------------------------------------------------------
 * UNIT TEST TARGET:
 * Coordinator.newRoom(...)
 *
 * TEST COVERAGE:
 * 1) Throws host-limit error when user already hosts max rooms
 * 2) Creates room successfully when user hasn't reached limit
 *
 * SCOPE:
 * - FirestoreService.getUser (if needed)
 *
 * OUT OF SCOPE:
 * - ViewModels
 * - UI
 * - RTDB room creation
 * - Analytics side effects
 *
 * TEST TYPE:
 * Pure unit test (Coordinator-level)
 * ====================================================================
 */

//External package
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

//Internal package
import 'package:what2eat/models/user.dart';
import '../mocks/mocks.dart';

void main() {
  // initialised in setUp
  late MockFirestoreService mockDb;
  late TestCoordinator coordinator;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{}); // Vital for any() with Maps
    registerFallbackValue(''); 
    registerCoordinatorFallbacks();
  });

  setUp(() {
    // Initialize mock first
    mockDb = MockFirestoreService();

    // Then create coordinator with mock
    coordinator = TestCoordinator(
      db: mockDb,
      auth: MockAuthService(),
      rtdb: MockRTDBService(),
    );
  });

  test('newRoom throws host-limit error if user already hosts max rooms', () {
    // User already hosting max rooms (limit is 5)
    final user = UserModel(
      uid: 'u1',
      email: 'a@test.com',
      username: 'Alice',
      dietaryRestrictions: [],
      preferredCuisine: [],
      hostedRooms: List.filled(5, 'room_id'), // host limit reached
    );

    // should throw StateError before any Firestore calls
    expect(
      () => coordinator.newRoom(currentUser: user),
      throwsA(isA<StateError>()),
    );

    // Verify no Firestore calls were made
    verifyNever(() => mockDb.getUser(any()));
    verifyNever(() => mockDb.setRoom(any(), any()));
  });

  test('newRoom succeeds if user has not reached host limit', () async {
    // Set up test data
    final fakeUserModel = UserModel(
      uid: 'u1',
      email: 'a@test.com',
      username: '',
      dietaryRestrictions: [],
      preferredCuisine: [],
      hostedRooms: [],
    );

    coordinator.manualRoomId = 'room_new_123';

    // IMPORTANT: You need to stub ALL methods that will be called
    // 1. Stub getRoom (called by generateRoomId)
    when(() => mockDb.getRoom(any()))
        .thenAnswer((_) async => null);

    // 2. Stub setRoom (called by createRoom)
    // Make sure to match the exact signature including optional parameter
    when(() => mockDb.setRoom(any(), any(), merge: any(named: 'merge')))
        .thenAnswer((_) async {});

    // Act
    final updatedUser = await coordinator.newRoom(currentUser: fakeUserModel);

    // Assert
    expect(updatedUser.hostedRooms, contains('room_new_123'));
    
    // Verify setRoom was called
    verify(() => mockDb.setRoom(any(), any(), merge: any(named: 'merge'))).called(1);
  });

}