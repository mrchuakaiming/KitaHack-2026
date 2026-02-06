import firebase_admin
from firebase_admin import db

# Initialize Firebase Admin at server start
# firebase_admin.initialize_app(options={
#     'databaseURL': 'https://<YOUR_PROJECT_ID>.firebaseio.com/'
# })

class RTDBService:
    """
    Minimal RTDB service for participant tracking and auto-cleanup.

    Structure follows client-side RTDB:
    participants
      └── {room_id}
           └── {uid}
                ├── submitted: bool
                └── disconnectedAt: timestamp (set by onDisconnect)
    """

    def __init__(self):
        self.root_ref = db.reference()  # Root reference

    def register_disconnect(self, room_id: str, uid: str) -> None:
        """
        Registers an onDisconnect marker for a participant.
        The client calls this via 'leaveRoom' function in Coordinator.
        """
        try:
            participant_ref = self.root_ref.child(f'participants/{room_id}/{uid}')
            # Clear previous disconnectedAt in case of reconnection
            participant_ref.child('disconnectedAt').delete()
            # Set disconnectedAt on client disconnect
            participant_ref.on_disconnect().update({
                'disconnectedAt': db.SERVER_TIMESTAMP
            })
        except Exception as e:
            print(f"[RTDBService] Failed to register disconnect for {uid}: {e}")
            raise

    def delete_participant(self, room_id: str, uid: str) -> None:
        """
        Deletes a single participant from a room.
        Server can call this if participant is offline and not host/done.
        """
        try:
            self.root_ref.child(f'participants/{room_id}/{uid}').delete()
        except Exception as e:
            print(f"[RTDBService] Failed to delete participant {uid}: {e}")
            raise

    def delete_room(self, room_id: str) -> None:
        """
        Deletes all participants in a room.
        Typically called when room expires.
        """
        try:
            self.root_ref.child(f'participants/{room_id}').delete()
        except Exception as e:
            print(f"[RTDBService] Failed to delete room {room_id}: {e}")
            raise
