"""
cleanup_service.py

Cleanup tasks for:
  1. Offline participants (disconnected_at + not submitted)
  2. Expired rooms

Designed for use with Cloud Functions or background scheduling.
"""

import time
from datetime import datetime, timezone

from ..utils.rtdb_service import RTDBService
from ..utils.firestore_helpers import FirestoreService

# Threshold for offline participants in milliseconds (5 minutes)
OFFLINE_THRESHOLD_MS = 5 * 60 * 1000  

# ============================
# SERVICE INSTANCES
# ============================
rtdb_service = RTDBService()
firestore_service = FirestoreService()


# ============================
# OFFLINE PARTICIPANT CLEANUP
# ============================
async def cleanup_offline_participants():
    """
    Remove participants who are offline (disconnected_at older than threshold)
    and have not submitted, across all rooms.
    """
    try:
        rooms_snapshot = rtdb_service.root_ref.child('participants').get()
        if not rooms_snapshot:
            return

        now_ms = int(time.time() * 1000)

        for room_id, participants in rooms_snapshot.items():
            for uid, pdata in participants.items():
                disconnected_at = pdata.get('disconnected_at')
                submitted = pdata.get('submitted', False)

                if disconnected_at and not submitted:
                    if now_ms - disconnected_at >= OFFLINE_THRESHOLD_MS:
                        print(f"[Cleanup] Removing offline participant {uid} from room {room_id}")
                        await rtdb_service.delete_participant(room_id=room_id, uid=uid)

    except Exception as e:
        print(f"[Cleanup] Failed offline participant cleanup: {e}")


# ============================
# EXPIRED ROOM CLEANUP
# ============================
async def cleanup_expired_rooms():
    """
    Delete rooms whose expiryTime has passed.
    Also removes RTDB participants and Firestore preferences.
    """
    try:
        rooms = firestore_service.get_all_rooms()  # List of room dicts
        if not rooms:
            return

        now_ts = datetime.now(timezone.utc).timestamp()

        for room in rooms:
            room_id = room.get('room_id')
            expiry = room.get('expiryTime')
            if expiry and expiry.timestamp() <= now_ts:
                print(f"[Cleanup] Deleting expired room {room_id}")

                # Delete participants in RTDB
                await rtdb_service.delete_room(room_id)

                # Delete preferences in Firestore
                firestore_service.delete_preferences(room_id)

                # Delete the room itself
                firestore_service.delete_room(room_id)

    except Exception as e:
        print(f"[Cleanup] Failed expired room cleanup: {e}")
