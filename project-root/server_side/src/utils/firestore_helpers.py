import firebase_admin
from firebase_admin import firestore

# Initialize Firebase Admin (once per server)
# firebase_admin.initialize_app()

class FirestoreService:
    """
    Minimal server-side Firestore service.
    Handles:
      - Fetching rooms for AI or cleanup
      - Deleting expired rooms, preferences, users
    """

    def __init__(self):
        self.db = firestore.client()

    # ---------------------------- ROOMS ----------------------------
    def get_room(self, room_id: str) -> dict | None:
        """Fetch a room document for AI analysis."""
        doc = self.db.collection('rooms').document(room_id).get()
        return doc.to_dict() if doc.exists else None

    def get_all_rooms(self) -> list[dict]:
        """Fetch all room documents (used for cleanup)."""
        rooms = self.db.collection('rooms').stream()
        return [room.to_dict() for room in rooms]

    def delete_room(self, room_id: str):
        """Delete a room document."""
        self.db.collection('rooms').document(room_id).delete()

    # ---------------------------- PREFERENCES ----------------------------
    def delete_preferences(self, room_id: str):
        """
        Delete all preference documents for a room.
        Assumes preferences are stored with a 'room_id' field.
        """
        prefs = self.db.collection('preferences').where('room_id', '==', room_id).stream()
        for pref in prefs:
            pref.reference.delete()

    # ---------------------------- USERS ----------------------------
    def delete_user(self, uid: str):
        """Delete a user document if needed."""
        self.db.collection('users').document(uid).delete()
