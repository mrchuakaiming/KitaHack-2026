import firebase_admin
from firebase_admin import db

# Initialize Firebase Admin at server start
# firebase_admin.initialize_app(options={
#     'databaseURL': 'https://<YOUR_PROJECT_ID>.firebaseio.com/'
# })

class RTDBService:
    """
    Minimal RTDB service for online presence tracking and room cleanup.
    """

    def __init__(self):
        self.root_ref = db.reference()  # Root reference

    def set_user_online(self, room_id: str, uid: str) -> None:
        """
        Mark a user as online in a room.
        This is mostly updated by client heartbeats or presence listener.
        """
        try:
            ref = self.root_ref.child(f'rooms/{room_id}/participants/{uid}')
            # Write online timestamp
            ref.set({'last_seen': db.SERVER_TIMESTAMP})
            # Automatically remove when client disconnects
            ref.on_disconnect().remove()
        except Exception as e:
            print(f"[RTDBService] Failed to set user online: {e}")
            raise

    def delete_room(self, room_id: str) -> None:
        """
        Delete all participants for a room.
        Can be called by Cloud Functions when room expires.
        """
        try:
            self.root_ref.child(f'rooms/{room_id}').delete()
        except Exception as e:
            print(f"[RTDBService] Failed to delete room: {e}")
            raise
