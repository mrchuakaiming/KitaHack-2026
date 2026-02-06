"""
cleanup_service.py

Periodic cleanup of:
  1. Offline participants (disconnectedAt + not submitted)
  2. Expired rooms

This file should be imported in main.py and run as a background task.
"""

import asyncio
import time
from datetime import datetime, timezone

from rtdb_service import RTDBService
from firestore_helpers import FirestoreService

# Interval for checking in seconds (e.g., every 5 minutes)
CHECK_INTERVAL = 300  

# Threshold for offline participants (e.g., 5 minutes)
OFFLINE_THRESHOLD_MS = 5 * 60 * 1000  

rtdb_service = RTDBService()
firestore_service = FirestoreService()


async def run_periodic_cleanup():
    """
    Background task to clean up offline participants and expired rooms.
    """
    while True:
        try:
            print("[Cleanup] Running periodic cleanup...")
            await cleanup_offline_participants()
            await cleanup_expired_rooms()
        except Exception as e:
            print(f"[Cleanup] Error during cleanup: {e}")
        await asyncio.sleep(CHECK_INTERVAL)


async def cleanup_offline_participants():
    """
    Remove participants who are offline (disconnectedAt older than threshold)
    and have not submitted, for all rooms.
    """
    try:
        # Fetch all rooms from RTDB participants table
        rooms_snapshot = rtdb_service.root_ref.child('participants').get()
        if not rooms_snapshot:
            return

        now_ms = int(time.time() * 1000)

        for room_id, participants in rooms_snapshot.items():
            for uid, pdata in participants.items():
                disconnected_at = pdata.get('disconnectedAt')
                submitted = pdata.get('submitted', False)

                if disconnected_at and not submitted:
                    # If offline longer than threshold
                    if now_ms - disconnected_at >= OFFLINE_THRESHOLD_MS:
                        print(f"[Cleanup] Removing offline participant {uid} in room {room_id}")
                        await rtdb_service.delete_participant(room_id=room_id, uid=uid)
    except Exception as e:
        print(f"[Cleanup] Failed offline participant cleanup: {e}")

async def cleanup_expired_rooms():
    """
    Delete rooms that have expired based on Firestore Room.expiryTime
    and remove participants and preferences as well.
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

                # Delete the Room document itself
                firestore_service.delete_room(room_id)

    except Exception as e:
        print(f"[Cleanup] Failed expired room cleanup: {e}")
