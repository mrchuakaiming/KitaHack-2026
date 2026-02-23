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
def cleanup_offline_participants():
    """
    Remove participants who have been offline beyond the allowed threshold 
    and have not submitted, across all rooms in the Realtime Database (RTDB).

    This function performs the following steps:
    1. Retrieves all participants from all rooms in RTDB.
    2. Checks each participant's `disconnected_at` timestamp.
    3. Deletes participants whose offline duration exceeds `OFFLINE_THRESHOLD_MS`
       and who have not submitted their data.

    The offline threshold is defined by `OFFLINE_THRESHOLD_MS` (default 5 minutes).

    Raises:
        Exception: If there is an error retrieving participants or deleting them 
                   from RTDB.
    """
    try:
        # Retrieve all participants across all rooms from RTDB
        rooms_snapshot = rtdb_service.root_ref.child('participants').get()
        if not rooms_snapshot: #If not participants, no need to clean
            return

        #current time in ms
        now_ms = int(time.time() * 1000)

        #Iterate over each room and its participants
        for room_id, participants in rooms_snapshot.items():
            for uid, pdata in participants.items():
                #get the disconnected timestamp
                disconnected_at = pdata.get('disconnected_at')
                #check whether they submitted data
                submitted = pdata.get('submitted', False)
                
                # Only consider participants who have disconnected and not submitted
                if disconnected_at and not submitted:
                    # Check if the participant has been offline longer than the threshold
                    if now_ms - disconnected_at >= OFFLINE_THRESHOLD_MS:
                        # Remove participant from the room in RTDB (async operation)
                        # CHANGED: Removed 'await' - this is now synchronous
                        rtdb_service.delete_participant(room_id=room_id, uid=uid)

    except Exception as e:
        raise Exception(f"[Cleanup] Failed offline participant cleanup: {e}")


# ============================
# EXPIRED ROOM CLEANUP
# ============================
def cleanup_expired_rooms():
    """
    Delete all rooms whose expiryTime has passed.

    This function performs the following cleanup tasks for each expired room:
    1. Deletes participants in the room from the Realtime Database (RTDB).
    2. Deletes user preferences associated with the room from Firestore.
    3. Deletes the room itself from Firestore.

    The current time is compared with each room's `expiryTime` to determine
    if the room has expired. Only expired rooms are processed.

    Raises:
        Exception: If there is an error retrieving rooms or deleting data 
                   from RTDB or Firestore.
    """
    try:
        # Fetch all rooms from Firestore.
        rooms = firestore_service.get_all_rooms()  # List of room dicts
        if not rooms: #If no any room
            return

        # Current UTC timestamp in seconds
        now_ts = datetime.now(timezone.utc).timestamp()

        for room in rooms:
            room_id = room.get('room_id') #get room id 
            expiry = room.get('expiryTime') #the timestamp
            if expiry and expiry.timestamp() <= now_ts:
                #RTDB cleanup
                # Delete participants in RTDB
                # [CHANGE]: Removed 'await' because delete_room is synchronous
                rtdb_service.delete_room(room_id)

                #Firestore cleanup
                # Delete preferences in Firestore
                # [CHANGE]: Removed 'await' - assuming FirestoreService is also synchronous
                firestore_service.delete_preferences(room_id)
                # Delete the room itself
                # [CHANGE]: Removed 'await'
                firestore_service.delete_room(room_id)

    except Exception as e:
        raise Exception(f"[Cleanup] Failed expired room cleanup: {e}")
