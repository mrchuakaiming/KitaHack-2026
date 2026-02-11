/*
 * ====================================================================
 * unit_test.dart
 * --------------------------------------------------------------------
 * PURPOSE:
 * Base test configuration for coordinator unit tests.
 *
 * INCLUDES:
 * - TestCoordinator base wiring
 * - Common setup / teardown logic
 *
 * NOTES:
 * - All mocks and fakes live in mocks.dart
 *
 * TEST TYPE:
 * Unit testing infrastructure
 * ====================================================================
 */
// External package
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Internal package
import 'package:what2eat/coordinators/coordinator.dart'; //functions
import 'package:what2eat/models/user.dart'; //models
import 'package:what2eat/models/preferences.dart';//models
import '../mocks/mocks.dart';//mock

void main() {
  // later initialise in setUp
  late MockAuthService mockAuth;
  late MockFirestoreService mockDb;
  late MockUserCredential mockCredential;
  late MockFirebaseUser mockUser;
  late MockRTDBService mockRtdb;
  late MockAIService mockAi;
  late TestCoordinator coordinator; // Use the wrapper

  setUpAll(() {
    
    registerCoordinatorFallbacks();// when any() expects unknown type ie. any<UserModel>()
    registerFallbackValue(<String, dynamic>{}); // when any() expects a Maps
    registerFallbackValue(''); // whenever any() expects a string
  });

  setUp(() {
    //Initialise all the mocks
    //Firebase Auth
    mockAuth = MockAuthService();
    mockCredential = MockUserCredential();
    mockUser = MockFirebaseUser();
    //Firestore
    mockDb = MockFirestoreService();
    //Firebase rtdb
    mockRtdb = MockRTDBService();
    mockAi = MockAIService();

    // stub all rtdb methods that will be call
    when(() => mockRtdb.getParticipants(any())).thenAnswer((_) async => {});

    when(() => mockRtdb.setParticipantSubmitted(
      roomId: any(named: 'roomId'),
      uid: any(named: 'uid'),
      submitted: any(named: 'submitted'),
    )).thenAnswer((_) async {}); 

    when(() => mockRtdb.clearDisconnectedAt(
      roomId: any(named: 'roomId'),
      uid: any(named: 'uid'),
    )).thenAnswer((_) async {});

    when(() => mockRtdb.registerOnDisconnect(
      roomId: any(named: 'roomId'),
      uid: any(named: 'uid'),
    )).thenAnswer((_) async {});

    when(() => mockRtdb.deleteRoomParticipants(any())).thenAnswer((_) async {});
    
    // stub AI service
    when(() => mockAi.sendPreferencesData(
      participants: any(named: 'participants'),
    )).thenAnswer((_) async => {});

    // Default stub for replaceUser
    when(() => mockDb.replaceUser(any())).thenAnswer((_) async {});
    // Stub the Firebase UserCredential and User objects
    when(() => mockCredential.user).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('u1');
    when(() => mockUser.email).thenReturn('a@test.com');

    //Use the already-stubbed mocks when creating TestCoordinator
    coordinator = TestCoordinator(
      auth: mockAuth,
      db: mockDb,
      rtdb: mockRtdb,  // Use the stubbed mockRtdb
      maps: MockMapsService(),
      ai: mockAi,      // Use the stubbed mockAi
    );
    
  });

  /*
  * ====================================================================
  * 0. helper function tests
  * --------------------------------------------------------------------
  * UNIT TEST TARGET:
  * Coordinator.getOrCreateUserModel(...)
  *
  * TEST COVERAGE:
  * 1) Returns existing Firestore user when found
  * 2) Creates and persists a default user when missing
  *
  * TEST TYPE:
  * Pure unit test (Firestore mocked, no Firebase initialization)
  * ====================================================================
  */

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

  /*
  * ====================================================================
  * registerUser tests
  * --------------------------------------------------------------------
  * UNIT TEST TARGET:
  * Coordinator.registerUser(...)
  *
  * TEST COVERAGE:
  * 1) Creates Firebase Auth user
  * 2) Persists initial user profile in Firestore
  * 3) Returns populated UserModel on success
  * 4) Rolls back Auth user and throws if Firestore write fails
  *
  * TEST TYPE:
  * Pure unit test (all Firebase services mocked)
  * ====================================================================
  */

  group('registerUser',(){
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
    });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  * Coordinator.logIn(...)
  *
  * TEST COVERAGE:
  * - Authenticates user via AuthService
  * - Fetches and returns enriched UserModel from Firestore
  *
  * TEST TYPE:
  * Pure unit test (all Firebase services mocked)
  * ====================================================================
  */
  group('logIn',(){
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
      // simulate Firebase Auth throwing an exception (wrong password, network error, etc.)
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
  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  * Coordinator.newRoom(...)
  *
  * TEST COVERAGE:
  * - Throws host-limit error when user has reached maximum hosted rooms
  * - Creates a new room when host limit is not exceeded
  *
  * TEST TYPE:
  * Pure unit test (FirestoreService mocked)
  * ====================================================================
  */
  group('newRoom',(){
    // reached limit == failed
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

    // haven't reach the limit == success
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

      // getRoom (called by generateRoomId)
      when(() => mockDb.getRoom(any()))
          .thenAnswer((_) async => null);

      // setRoom (called by createRoom)
      // Make sure to match the exact signature including optional parameter
      when(() => mockDb.setRoom(any(), any(), merge: any(named: 'merge')))
          .thenAnswer((_) async {});

      // run newRoom
      final updatedUser = await coordinator.newRoom(currentUser: fakeUserModel);

      // Assert: UserModel includes new room Id
      expect(updatedUser.hostedRooms, contains('room_new_123'));
      
      // Verify setRoom was called
      verify(() => mockDb.setRoom(any(), any(), merge: any(named: 'merge'))).called(1);
    });

  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  * Coordinator.joinRoom(...)
  *
  * TEST COVERAGE:
  * - Throws on invalid room ID
  * - Throws if room does not exist
  * - Host first join creates participant and returns 'host'
  * - Non-host with submitted preference returns 'done_user'
  * - Non-host first join creates participant and returns 'undone_user'
  * - Returning undone user clears disconnected state and returns 'undone_user'
  *
  * TEST TYPE:
  * Pure unit test (Firestore & RTDB mocked)
  * ====================================================================
  */
    group('joinRoom', () {
    // Not valid roomId
    test('throws if roomId is empty', () async {
      //should throw StateError with message 'invalid-room-id'
      await expectLater(
        () => coordinator.joinRoom(roomId: '   ', uid: 'u1'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'invalid-room-id')),
      );
    });

    //No this room 
    test('throws if room not found', () async {
      when(() => mockDb.getRoom(any())).thenAnswer((_) async => null);
      //should throw StateError with message 'room-not-found'
      await expectLater(
        () => coordinator.joinRoom(roomId: 'r1', uid: 'u1'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'room-not-found')),
      );
    });

    //Host join
    test('returns "host" and creates participant if host first join', () async {
      final roomData = {'host_uid': 'u1'}; // Room exists, uid is host
      when(() => mockDb.getRoom('r1')).thenAnswer((_) async => roomData);
      when(() => mockRtdb.getParticipants('r1')).thenAnswer((_) async => {});
      when(() => mockRtdb.setParticipantSubmitted(
        roomId: 'r1', uid: 'u1', submitted: true
      )).thenAnswer((_) async {});
      
      // Coordinator should mark host as submitted and return 'host'
      final result = await coordinator.joinRoom(roomId: 'r1', uid: 'u1');

      expect(result, 'host');
      verify(() => mockRtdb.setParticipantSubmitted(roomId: 'r1', uid: 'u1', submitted: true)).called(1);
    });

    //done_user join again
    test('returns "done_user" and clears disconnected_at if non-host already submitted', () async {

      final roomData = {'host_uid': 'host1'};
      final participants = {
        'u2': {'submitted': true, 'disconnected_at': 1234567890}
      };

      when(() => mockDb.getRoom('r1')).thenAnswer((_) async => roomData);
      when(() => mockRtdb.getParticipants('r1')).thenAnswer((_) async => participants);
      when(() => mockRtdb.clearDisconnectedAt(roomId: 'r1', uid: 'u2')).thenAnswer((_) async {});
      
      // Coordinator should clear disconnected_at and return 'done_user'
      final result = await coordinator.joinRoom(roomId: 'r1', uid: 'u2');

      expect(result, 'done_user');
      verify(() => mockRtdb.clearDisconnectedAt(roomId: 'r1', uid: 'u2')).called(1);
    });

    //Not done_user and not host first join
    test('returns "undone_user" and creates participant if non-host first join', () async {
      final roomData = {'host_uid': 'host1'};
      when(() => mockDb.getRoom('r1')).thenAnswer((_) async => roomData);
      when(() => mockRtdb.getParticipants('r1')).thenAnswer((_) async => {});
      when(() => mockRtdb.setParticipantSubmitted(roomId: 'r1', uid: 'u2', submitted: false))
          .thenAnswer((_) async {});

      final result = await coordinator.joinRoom(roomId: 'r1', uid: 'u2');

      // Coordinator should create participant with submitted=false and return 'undone_user'
      expect(result, 'undone_user');
      verify(() => mockRtdb.setParticipantSubmitted(roomId: 'r1', uid: 'u2', submitted: false)).called(1);
    });

    //Not done_user and not first join
    test('returns "undone_user" and clears disconnected_at if returning undone user', () async {
      final roomData = {'host_uid': 'host1'};
      final participants = {
        'u2': {'submitted': false, 'disconnected_at': 1234567890}
      };

      when(() => mockDb.getRoom('r1')).thenAnswer((_) async => roomData);
      when(() => mockRtdb.getParticipants('r1')).thenAnswer((_) async => participants);
      when(() => mockRtdb.clearDisconnectedAt(roomId: 'r1', uid: 'u2')).thenAnswer((_) async {});

      // Coordinator should clear disconnected_at and return 'undone_user'
      final result = await coordinator.joinRoom(roomId: 'r1', uid: 'u2');

      expect(result, 'undone_user');
      verify(() => mockRtdb.clearDisconnectedAt(roomId: 'r1', uid: 'u2')).called(1);
    });
  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  * Coordinator.submitPreference(...)
  *
  * TEST COVERAGE:
  * - Writes preference data to Firestore
  * - Marks participant as submitted in RTDB
  * - Returns true on success
  *
  * TEST TYPE:
  * Pure unit test (Firestore & RTDB mocked)
  * ====================================================================
  */

  group('Submit Preferences', (){
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
  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  * Coordinator.leaveRoom(...)
  *
  * TEST COVERAGE:
  * - Calls RTDBService.registerOnDisconnect with correct roomId and uid
  * - Throws when RTDBService.registerOnDisconnect fails
  *
  * TEST TYPE:
  * Pure unit test (RTDB mocked via TestCoordinator)
  * ====================================================================
  */
  group('leaveRoom', () {
    //leave room success
    test('calls registerOnDisconnect with correct parameters', () async {
      when(() => mockRtdb.registerOnDisconnect(roomId: 'r1', uid: 'u1'))
          .thenAnswer((_) async {});

      await coordinator.leaveRoom(roomId: 'r1', uid: 'u1');

      verify(() => mockRtdb.registerOnDisconnect(roomId: 'r1', uid: 'u1')).called(1);
    });

    //leave room failed (then wait for room expiry to clean it)
    test('throws if RTDBService.registerOnDisconnect fails', () async {
      when(() => mockRtdb.registerOnDisconnect(roomId: 'r1', uid: 'u1'))
          .thenThrow(Exception('RTDB failed'));

      await expectLater(
        () => coordinator.leaveRoom(roomId: 'r1', uid: 'u1'),
        throwsA(predicate((e) =>
            e.toString().contains('[ERROR] Failed to register leaveRoom') &&
            e.toString().contains('RTDB failed'))),
      );

      verify(() => mockRtdb.registerOnDisconnect(roomId: 'r1', uid: 'u1')).called(1);
    });
  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  *  - generateRecommendation(...)
  *  - storeRecommendation(...)
  *  - wantResult(...)
  *
  * TEST COVERAGE:
  * - generateRecommendation calls AIService with room preferences
  * - storeRecommendation updates Firestore and clears RTDB participants
  * - wantResult updates done_users field in Firestore
  * - Proper error handling when dependencies fail
  *
  * TEST TYPE:
  * Pure unit test (TestCoordinator + mocks, no network)
  * ====================================================================
  */
  group('Generate Recommendation', () {
    group('generateRecommendation', () {
      test('calls AIService with preferences and returns result', () async {
        //Stub Firestore to return preferences and AIService to return result
        final roomId = 'r1';
        final fakePrefs = [
          PreferencesModel(
            roomId: roomId,
            livePreferences: [
              {'restaurant': 'p1', 'cuisine': 'Italian'},
            ],
            preferredCuisine: ['Italian'],
            budget: [10, 50],
            dietaryRestrictions: [],
          ).toJson()
        ];

        final aiResult = {
          'recommended_place_id': 'p1',
          'recommended_cuisine': 'Italian',
          'budget': "",
          'justification': 'Most users prefer Italian',
        };

        when(() => mockDb.getAllPreferencesForRoom(roomId))
            .thenAnswer((_) async => fakePrefs);

        when(() => mockAi.sendPreferencesData(participants: any(named: 'participants')))
            .thenAnswer((_) async => aiResult);

        //Call generateRecommendation
        final result = await coordinator.generateRecommendation(roomId: roomId);

        // assert: Result matches expected AI output
        expect(result, aiResult);

        // verify: Firestore and AIService called once
        verify(() => mockDb.getAllPreferencesForRoom(roomId)).called(1);
        verify(() => mockAi.sendPreferencesData(participants: any(named: 'participants'))).called(1);
      });

      test('throws if no preferences exist', () async {
        // Firestore to return empty list
        final roomId = 'r1';
        when(() => mockDb.getAllPreferencesForRoom(roomId)).thenAnswer((_) async => []);

        //generateRecommendation throws expected error
        await expectLater(
          () => coordinator.generateRecommendation(roomId: roomId),
          throwsA(predicate((e) => e.toString().contains('No preferences submitted')))
        );
      });
    });

    group('storeRecommendation', () {
      test('updates Firestore and deletes RTDB participants, returns success', () async {
        //Stub Firestore update and RTDB deletion
        final roomId = 'r1';
        final aiResult = {
          "recommended_place_id": "Sushi Place",
          "recommended_cuisine": null,
          "budget": "20-50",
          "justification": "Best match for preferences",
        };

        
        // Stub Firestore updateRoom and RTDB deletion
        when(() => mockDb.updateRoom(roomId, any())).thenAnswer((_) async {});
        when(() => mockRtdb.deleteRoomParticipants(roomId)).thenAnswer((_) async {});

        // Call storeRecommendation
        final status = await coordinator.storeRecommendation(
          roomId: roomId,
          result: aiResult,
        );

        // Assert: Function returns 'success'
        expect(status, 'success');

        // Expected output format stored in Firestore
        final expectedOutput = {
          "suggestion": aiResult["recommended_place_id"] ?? aiResult["recommended_cuisine"],
          "justification": aiResult["justification"],
          "price_range": aiResult["budget"] ?? "",
        };

        // Verify: Firestore and RTDB methods called correctly
        verify(() => mockDb.updateRoom(roomId, {
              'output': expectedOutput,
            })).called(1);

        verify(() => mockRtdb.deleteRoomParticipants(roomId)).called(1);
      });

      test('returns error string if updateRoom fails', () async {
        //Stub Firestore to throw error
        final roomId = 'r1';
        final result = {'suggestion': 'X', 'justification': 'Y','price_range:': ''};

        // Stub Firestore failure
        when(() => mockDb.updateRoom(roomId, any())).thenThrow(Exception('Firestore fail'));

        // Call storeRecommendation and expect it to throw
        await expectLater(
          () => coordinator.storeRecommendation(
            roomId: roomId,
            result: result,
          ),
          throwsA(
            predicate((e) => 
              e is Exception && 
              e.toString().contains('Failed to store recommendation')
            )
          ),
        );
      });

    });
    group('wantResult', () {
      test('returns output from Firestore', () async {
        // stub Firestore to return a room with output
        final roomId = 'r1';
        final fakeOutput = {
          'suggestion': 'Sushi Place',
          'justification': 'Best match for preferences',
          'price_range': '20-50',
        };

        when(() => mockDb.getRoom(roomId)).thenAnswer((_) async => {
              'room_id': roomId,
              'host_uid': 'host1',
              'output': fakeOutput,
            });

        //call wantResult
        final result = await coordinator.wantResult(roomId: roomId);

        // Assert: verify Firestore getRoom was called and output returned
        verify(() => mockDb.getRoom(roomId)).called(1);
        expect(result, fakeOutput);
      });

      test('throws if room not found', () async {
        // stub Firestore to return null
        final roomId = 'r1';
        when(() => mockDb.getRoom(roomId)).thenAnswer((_) async => null);

        // Expect room-not-found error
        await expectLater(
          () => coordinator.wantResult(roomId: roomId),
          throwsA(predicate((e) => e.toString().contains('room-not-found'))),
        );
      });

      test('throws if output field is missing', () async {
        // stub Firestore to return room without output
        final roomId = 'r1';
        when(() => mockDb.getRoom(roomId)).thenAnswer((_) async => {
              'room_id': roomId,
              'host_uid': 'host1',
              // no 'output' field
            });

        // Expect output-not-found error
        await expectLater(
          () => coordinator.wantResult(roomId: roomId),
          throwsA(predicate((e) => e.toString().contains('output-not-found'))),
        );
      });

      test('throws if Firestore getRoom fails', () async {
        // stub Firestore to throw exception
        final roomId = 'r1';
        when(() => mockDb.getRoom(roomId)).thenThrow(Exception('Firestore fail'));

        // Act & Assert: expect generic exception
        await expectLater(
          () => coordinator.wantResult(roomId: roomId),
          throwsA(predicate((e) => e.toString().contains('Failed to get room output'))),
        );
      });

    });
  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  *  - Coordinator.resetPassword(...)
  *
  * TEST COVERAGE:
  * - Calls AuthService with trimmed email
  * - Throws readable exception if AuthService fails
  *
  * TEST TYPE:
  * Pure unit test (TestCoordinator + mocks)
  * ====================================================================
  */
  group('Change Password',(){
    //test success
      test('resetPassword calls AuthService with trimmed email', () async {
      when(() => mockAuth.resetPassword(any())).thenAnswer((_) async {});

      await coordinator.resetPassword('  test@example.com  ');

      // Verify email is trimmed before calling AuthService
      verify(() => mockAuth.resetPassword('test@example.com')).called(1);
    });

    //auth failed
    test('resetPassword throws readable exception if AuthService fails', () async {
      when(() => mockAuth.resetPassword(any())).thenThrow(Exception('Firebase failed'));

      expect(
        () async => await coordinator.resetPassword('user@test.com'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Failed to reset password'))),
      );
    });
  });

  /*
  * ====================================================================
  * UNIT TEST TARGET:
  *  - Coordinator.deleteAccount(...)
  *
  * TEST COVERAGE:
  * - Successfully clears data and removes account
  * - Throws if no user is signed in
  * - Throws if clearData fails
  * - Throws if removeAcc fails
  *
  * TEST TYPE:
  * Pure unit test (TestCoordinator + mocks)
  * ====================================================================
  */
  group('Delete Account',(){
    //delete account successfully
    test('deleteAccount successfully clears data and removes account', () async {
      final mockUser = MockFirebaseUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      // Stub clearData and removeAcc to just complete
      when(() => mockDb.deleteUser('u1')).thenAnswer((_) async {});
      when(() => mockUser.delete()).thenAnswer((_) async {});

      await coordinator.deleteAccount();

      // Verify: Firestore delete was called
      verify(() => mockDb.deleteUser('u1')).called(1);

      // Verify: Firebase Auth delete was called
      verify(() => mockUser.delete()).called(1);
    });

    //If not signed in
    test('deleteAccount throws if no user is signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(
        () async => await coordinator.deleteAccount(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('No authenticated user'))),
      );
    });

    //clearData fails
    test('deleteAccount throws if clearData fails', () async {
      final mockUser = MockFirebaseUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockDb.deleteUser('u1')).thenThrow(Exception('Firestore failed'));

      expect(
        () async => await coordinator.deleteAccount(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Failed to delete account'))),
      );
    });

    //removeAcc fails
    test('deleteAccount throws if removeAcc fails', () async {
      final mockUser = MockFirebaseUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('u1');

      when(() => mockDb.deleteUser('u1')).thenAnswer((_) async {});
      when(() => mockUser.delete()).thenThrow(Exception('Auth deletion failed'));

      expect(
        () async => await coordinator.deleteAccount(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('Failed to delete account'))),
      );
    });
  });

}