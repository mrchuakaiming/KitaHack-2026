// integration_test/join_room_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/coordinators/coordinator.dart';

void joinRoomTests() {
  final coordinator = Coordinator();

  group('JOIN ROOM — Integration Tests', () {
    setUp(() async {
      // --- Arrange (suite prep): ensure isolation across tests ---
      // Clean Firestore "rooms" collection
      final fs = FirebaseFirestore.instance;
      final roomsSnap = await fs.collection('rooms').get();
      for (final d in roomsSnap.docs) {
        await d.reference.delete();
      }
      // Clean RTDB "participants" subtree
      final db = FirebaseDatabase.instance;
      await db.ref('participants').remove();
    });

    // -------------------------------------------------------------
    // 1) Successful join as host
    // -------------------------------------------------------------
    test('Host joins: creates/clears RTDB record and returns "host"', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      final db = FirebaseDatabase.instance;

      final roomId = 'ROOM_HOST_001';
      final hostUid = 'host_uid_abc';

      // Seed room doc with host_uid
      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': hostUid,
        'output': <String, dynamic>{},
      });

      // Pre-create a participant record with disconnected_at
      // to simulate a returning host who was previously offline.
      await db.ref('participants/$roomId/$hostUid').set({
        'submitted': true,
        'disconnected_at': ServerValue.timestamp,
      });

      // Act
      final role = await coordinator.joinRoom(roomId: roomId, uid: hostUid);

      // Assert
      expect(role, equals('host'));
      final snap =
          await db.ref('participants/$roomId/$hostUid').get();
      expect(snap.exists, isTrue);

      final data = Map<String, dynamic>.from(snap.value as Map);
      expect(data['submitted'], isTrue);
      // Ensure disconnected_at cleared by Coordinator
      expect(data.containsKey('disconnected_at'), isFalse);
    });

    // -------------------------------------------------------------
    // 2) Successful join as guest (first join, undone path)
    // -------------------------------------------------------------
    test('Guest joins (first time): creates submitted:false and returns "undone_user"', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      final db = FirebaseDatabase.instance;

      final roomId = 'ROOM_GUEST_001';
      final hostUid = 'host_uid_xyz';
      final guestUid = 'guest_uid_123';

      // Seed room with a different host
      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': hostUid,
        'output': <String, dynamic>{},
      });

      // Ensure guest has no prior RTDB record
      final guestRef = db.ref('participants/$roomId/$guestUid');
      await guestRef.remove();

      // Act
      final role = await coordinator.joinRoom(roomId: roomId, uid: guestUid);

      // Assert
      expect(role, equals('undone_user'));
      final snap = await guestRef.get();
      expect(snap.exists, isTrue);

      final data = Map<String, dynamic>.from(snap.value as Map);
      expect(data['submitted'], isFalse);
      expect(data.containsKey('disconnected_at'), isFalse);
    });

    // -------------------------------------------------------------
    // 3) Room ID does not exist
    // -------------------------------------------------------------
    test('Throws room-not-found if Firestore room is missing', () async {
      // Arrange
      final missingRoom = 'NO_SUCH_ROOM_999';
      final anyUid = 'uid_any';

      // Act & Assert
      await expectLater(
        () => coordinator.joinRoom(roomId: missingRoom, uid: anyUid),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('room-not-found'),
          ),
        ),
      );
    });
  });
}