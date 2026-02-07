/*
 * ====================================================================
 * COORDINATOR – SUBMIT PREFERENCE TEST
 * --------------------------------------------------------------------
 * UNIT TEST TARGET:
 * Coordinator.submitPreference(...)
 *
 * RESPONSIBILITIES VERIFIED:
 * - Writes preferences to Firestore
 * - Marks participant as submitted in RTDB
 * - Returns true on success
 *
 * TEST TYPE:
 * Pure unit test (no Firebase, no network)
 * ====================================================================
 */

// External packages
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Internal packages
import 'package:what2eat/models/preferences.dart';
import '../mocks/mocks.dart'; 

void main() {
  late MockFirestoreService mockDb;
  late MockRTDBService mockRtdb;
  late TestCoordinator coordinator;

  setUpAll(() {
    // Required by mocktail for any<UserModel>() or any<User>()
    registerCoordinatorFallbacks();
  });

  setUp(() {
    mockDb = MockFirestoreService();
    mockRtdb = MockRTDBService();

    // Initialise TestCoordinator with all mocks to prevent Firebase calls
    coordinator = TestCoordinator(
      db: mockDb,
      rtdb: mockRtdb,
      auth: MockAuthService(),
      maps: MockMapsService(),
      ai: MockAIService(),
    );
  });

  test('submitPreference writes preferences and marks RTDB', () async {
    // Prepare the input preferences
    final prefs = PreferencesModel(
      roomId: 'r1',
      livePreferences: [
        {'restaurant': 'place_id_1', 'cuisine': 'Italian'},
        {'restaurant': 'null', 'cuisine': 'Chinese'},
      ],
      preferredCuisine: ['Italian'],
      budget: [20, 50],
      dietaryRestrictions: ['Vegan'],
    );

    // Stub Firestore getUser so Coordinator does not fail
    // coordinator.submitPreference internally calls db
    when(() => mockDb.getUser(any())).thenAnswer((_) async => null);

    // Stub Firestore setPreferences 
    // (normally writes the user's preferences to Firestore)
    when(() => mockDb.setPreferences(
          roomId: any(named: 'roomId'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});

    // Stub RTDB setParticipantSubmitted
    // (marks a participant as "submitted")
    when(() => mockRtdb.setParticipantSubmitted(
          roomId: any(named: 'roomId'),
          uid: any(named: 'uid'),
          submitted: true,
        )).thenAnswer((_) async {});

    // call submitPreference to test
    final result = await coordinator.submitPreference(
      uid: 'u1',
      roomId: 'r1',
      preferences: prefs,
    );

    // Assert: submitPreference returned true
    expect(result, true);

    // Verify Firestore setPreferences was called
    verify(() => mockDb.setPreferences(
          roomId: 'r1',
          data: any(named: 'data'),
        )).called(1);

    // Verify RTDB setParticipantSubmitted was called
    verify(() => mockRtdb.setParticipantSubmitted(
          roomId: 'r1',
          uid: 'u1',
          submitted: true,
        )).called(1);
  });

  test('submitPreference throws if Firestore fails', () async {
    final prefs = PreferencesModel(
      roomId: 'r1',
      livePreferences: [
        {'restaurant': 'place_id_1', 'cuisine': 'Italian'},
      ],
      preferredCuisine: ['Italian'],
      budget: [20, 50],
      dietaryRestrictions: ['Vegan'],
    );

    // Stub getUser so Coordinator does not fail
    when(() => mockDb.getUser(any())).thenAnswer((_) async => null);

    // Make Firestore fail
    when(() => mockDb.setPreferences(
          roomId: any(named: 'roomId'),
          data: any(named: 'data'),
        )).thenThrow(Exception('Firestore failed'));

    // RTDB stub (won't be reached if Firestore fails)
    when(() => mockRtdb.setParticipantSubmitted(
          roomId: any(named: 'roomId'),
          uid: any(named: 'uid'),
          submitted: true,
        )).thenAnswer((_) async {});

    // Expect an exception
    await expectLater(
      () => coordinator.submitPreference(
        uid: 'u1',
        roomId: 'r1',
        preferences: prefs,
      ),
      throwsA(isA<Exception>()),
    );

  });


}
