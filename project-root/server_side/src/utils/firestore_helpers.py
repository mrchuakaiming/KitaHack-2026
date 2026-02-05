import firebase_admin
from firebase_admin import firestore

# Initialize Firebase Admin (once per server)
# firebase_admin.initialize_app()

class FirestoreService:
    """
    Minimal server-side Firestore service.
    Only handles:
      - Fetching room for AI context
      - Deleting expired rooms/users
    """

    def __init__(self):
        self.db = firestore.client()

    # ---------------------------- ROOMS ----------------------------
    def get_room(self, room_id: str) -> dict | None:
        """Fetch a room document for AI analysis."""
        doc = self.db.collection('rooms').document(room_id).get()
        return doc.to_dict() if doc.exists else None

    def delete_room(self, room_id: str):
        """Delete a room (used when expired)."""
        self.db.collection('rooms').document(room_id).delete()

    # ---------------------------- USERS ----------------------------
    def delete_user(self, uid: str):
        """Delete a user document if needed."""
        self.db.collection('users').document(uid).delete()
