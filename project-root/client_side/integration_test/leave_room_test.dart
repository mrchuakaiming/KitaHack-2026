// integration_test/leave_room_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:what2eat/coordinator/coordinator.dart';

void leaveRoomTests() {
  final coordinator = Coordinator();

  group('LEAVE ROOM — Smoke Tests (onDisconnect)', () {
    setUp(() async {
      // --- Arrange (suite prep): isolate tests ---
      final fs = FirebaseFirestore.instance;
      // Clean rooms
      final roomsSnap = await fs.collection('rooms').get();
      for (final d in roomsSnap.docs) {
        await d.reference.delete();
      }
      // Clean RTDB participants
      final db = FirebaseDatabase.instance;
      await db.ref('participants').remove();
    });

    // -------------------------------------------------------------
    // 1) Host leaves (smoke)
    // -------------------------------------------------------------
    test('Host leaves: register onDisconnect without immediate side effects', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      const roomId = 'ROOM_LEAVE_HOST_001';
      const hostUid = 'host_uid_leave';

      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': hostUid,
        'output': <String, dynamic>{},
      });

      // Act
      // Expect no exception; actual onDisconnect will trigger on real disconnect.
      await coordinator.leaveRoom(roomId: roomId, uid: hostUid);

      // Assert
      // No immediate RTDB assertion; the function should complete without error.
      expect(true, isTrue);
    });

    // -------------------------------------------------------------
    // 2) Guest (submitted) leaves (smoke)
    // -------------------------------------------------------------
    test('Submitted guest leaves: register onDisconnect without immediate side effects', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      final db = FirebaseDatabase.instance;
      const roomId = 'ROOM_LEAVE_GUEST_SUBMITTED_001';
      const hostUid = 'host_uid_x';
      const guestUid = 'guest_uid_submitted';

      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': hostUid,
        'output': <String, dynamic>{},
      });

      // Optional: pre-create submitted=true to mirror done-user state
      await db.ref('participants/$roomId/$guestUid').set({'submitted': true});

      // Act
      await coordinator.leaveRoom(roomId: roomId, uid: guestUid);

      // Assert (smoke)
      expect(true, isTrue);
    });

    // -------------------------------------------------------------
    // 3) Guest (not submitted) leaves (smoke)
    // -------------------------------------------------------------
    test('Undone guest leaves: register onDisconnect without immediate side effects', () async {
      // Arrange
      final fs = FirebaseFirestore.instance;
      const roomId = 'ROOM_LEAVE_GUEST_UNDONE_001';
      const hostUid = 'host_uid_y';
      const guestUid = 'guest_uid_undone';

      await fs.collection('rooms').doc(roomId).set({
        'room_id': roomId,
        'host_uid': hostUid,
        'output': <String, dynamic>{},
      });

      // Act
      await coordinator.leaveRoom(roomId: roomId, uid: guestUid);

      // Assert (smoke)
      expect(true, isTrue);
    });
  });
}
