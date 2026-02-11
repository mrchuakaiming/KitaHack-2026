// integration_test/new_room_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:what2eat/coordinators/coordinator.dart';
import 'package:what2eat/models/user.dart';

void newRoomTests() {
  final coordinator = Coordinator();

  group('NEW ROOM — Integration Tests', () {
    setUp(() async {
      // --- Arrange (suite prep): clean rooms collection for isolation ---
      final fs = FirebaseFirestore.instance;
      final roomsSnap = await fs.collection('rooms').get();
      for (final d in roomsSnap.docs) {
        await d.reference.delete();
      }
    });

    // -------------------------------------------------------------
    // 1) Successful new room generation
    // -------------------------------------------------------------
    test('Creates a new room and returns updated UserModel', () async {
      // Arrange
      final uid = 'host_success_uid';
      final currentUser = UserModel(
        uid: uid,
        username: 'host',
        email: 'host@example.com',
        dietaryRestrictions: const [],
        preferredCuisine: const [],
        hostedRooms: const [],
      );

      // Act
      final updated = await coordinator.newRoom(currentUser: currentUser);

      // Assert
      expect(updated.hostedRooms.length, currentUser.hostedRooms.length + 1);

      // Extract the newly created roomId
      final newRoomId = updated.hostedRooms
          .firstWhere((id) => !currentUser.hostedRooms.contains(id));

      // Verify Firestore document exists and has expected shape
      final doc =
          await FirebaseFirestore.instance.collection('rooms').doc(newRoomId).get();
      expect(doc.exists, true);

      final data = doc.data()!;
      expect(data['room_id'], equals(newRoomId));
      expect(data['host_uid'], equals(uid));
      expect(data['output'], isA<Map<String, dynamic>>());
      // Non-deterministic timestamps: assert presence & type only
      expect(data['createdTime'], isNotNull);
      expect(data['expiryTime'], isNotNull);
    });

    // -------------------------------------------------------------
    // 2) Host limit reached (>=5 rooms)
    // -------------------------------------------------------------
    test('Throws host-limit-reached when user already hosts 5 rooms', () async {
      // Arrange
      final currentUser = UserModel(
        uid: 'host_limit_uid',
        username: 'host',
        email: 'host@example.com',
        dietaryRestrictions: const [],
        preferredCuisine: const [],
        hostedRooms: const ['A1', 'B2', 'C3', 'D4', 'E5'], // length == 5
      );

      // Act & Assert
      await expectLater(
        () => coordinator.newRoom(currentUser: currentUser),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('host-limit-reached'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------
    // 3) No repeating room IDs across multiple creations
    //    (Create multiple rooms across multiple users to avoid host limit)
    // -------------------------------------------------------------
    test('Generated room IDs are unique within the batch', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      // Ensure rooms collection is empty from setUp()

      // We'll create 12 rooms: 3 users x 4 rooms each (< 5 limit)
      final users = <UserModel>[
        UserModel(
          uid: 'host_u1',
          username: 'u1',
          email: 'u1@example.com',
          dietaryRestrictions: const [],
          preferredCuisine: const [],
          hostedRooms: const [],
        ),
        UserModel(
          uid: 'host_u2',
          username: 'u2',
          email: 'u2@example.com',
          dietaryRestrictions: const [],
          preferredCuisine: const [],
          hostedRooms: const [],
        ),
        UserModel(
          uid: 'host_u3',
          username: 'u3',
          email: 'u3@example.com',
          dietaryRestrictions: const [],
          preferredCuisine: const [],
          hostedRooms: const [],
        ),
      ];

      final createdIds = <String>{};

      // Act
      for (var i = 0; i < users.length; i++) {
        var user = users[i];
        for (var j = 0; j < 4; j++) {
          final updated = await coordinator.newRoom(currentUser: user);
          // capture new id by diff
          final newId = updated.hostedRooms
              .firstWhere((id) => !user.hostedRooms.contains(id));
          createdIds.add(newId);
          // carry forward hostedRooms for capacity accounting
          user = updated;
        }
      }

      // Assert
      // 12 rooms created, all unique
      expect(createdIds.length, equals(12));

      // And each ID exists as a document in Firestore
      for (final id in createdIds) {
        final doc = await fs.collection('rooms').doc(id).get();
        expect(doc.exists, true, reason: 'Room $id should exist in Firestore');
      }
    });
  });
}