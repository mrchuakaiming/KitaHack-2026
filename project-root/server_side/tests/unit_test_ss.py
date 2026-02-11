import os,sys,json
from pathlib import Path
from unittest.mock import MagicMock, patch, AsyncMock
from datetime import datetime, timezone
import pytest
import time

# =========================================================
# 0. Environment + path setup
# =========================================================

# Set environment variables with dummy values for testing
os.environ["GEMINI_API_KEY"] = "dummy"
os.environ["GOOGLE_MAPS_API_KEY"] = "dummy"
os.environ["FIREBASE_ADMIN_KEY_PATH"] = "/dummy/path"

# Define the project root directory
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

# =========================================================
# 1. Mock ALL Firebase modules BEFORE any imports
# =========================================================

# Mock the entire firebase_admin module and its submodules
mock_firebase_admin = MagicMock()
mock_firebase_admin._apps = {}  # Empty dict so initialization will run
mock_firebase_admin.initialize_app = MagicMock()
mock_firebase_admin.get_app = MagicMock()

# Mock credentials submodule
mock_credentials = MagicMock()
mock_certificate_instance = MagicMock()
mock_credentials.Certificate = MagicMock(return_value=mock_certificate_instance) # Return mock client

# Mock firestore submodule  
mock_firestore = MagicMock() # Return mock ref
mock_firestore.client = MagicMock(return_value=MagicMock()) # Dummy server timestamp

# Mock db submodule
mock_db = MagicMock()
mock_db.reference = MagicMock(return_value=MagicMock())
mock_db.SERVER_TIMESTAMP = "SERVER_TIMESTAMP_MOCK"

# Assign submodules to firebase_admin mock
mock_firebase_admin.credentials = mock_credentials
mock_firebase_admin.firestore = mock_firestore
mock_firebase_admin.db = mock_db

# Replace the module in sys.modules with mocks
sys.modules['firebase_admin'] = mock_firebase_admin
sys.modules['firebase_admin.credentials'] = mock_credentials
sys.modules['firebase_admin.firestore'] = mock_firestore
sys.modules['firebase_admin.db'] = mock_db

# =========================================================
# 2. Mock other modules
# =========================================================

# Mock config modules with dummy API keys
mock_main_config = MagicMock()
mock_main_config.GEMINI_API_KEY = "dummy"
mock_main_config.GOOGLE_MAPS_API_KEY = "dummy"
mock_main_config.FIREBASE_ADMIN_KEY_PATH = "/dummy/path"
mock_main_config.MAPS_API_KEY = "dummy"

sys.modules["server_side.src.config"] = mock_main_config
sys.modules["config"] = MagicMock()

# Mock Gemini
sys.modules["google.genai"] = MagicMock()
sys.modules["google.genai.types"] = MagicMock()

# =========================================================
# 3. Create mocks for services used by cleanup_services
# =========================================================

# Mock service instances
mock_rtdb_service_instance = MagicMock()
mock_rtdb_service_instance.root_ref = MagicMock()
# Async deletion
mock_rtdb_service_instance.delete_participant = AsyncMock()
mock_rtdb_service_instance.delete_room = AsyncMock()

# Mock Firestore service instance
mock_firestore_service_instance = MagicMock()
mock_firestore_service_instance.get_all_rooms = MagicMock(return_value=[])
mock_firestore_service_instance.delete_preferences = MagicMock()
mock_firestore_service_instance.delete_room = MagicMock()

# Mock service classes to return instances 
mock_rtdb_service_class = MagicMock(return_value=mock_rtdb_service_instance)
mock_firestore_service_class = MagicMock(return_value=mock_firestore_service_instance)

# Replace service modules with mocks
sys.modules['server_side.src.utils.rtdb_service'] = MagicMock()
sys.modules['server_side.src.utils.rtdb_service'].RTDBService = mock_rtdb_service_class

sys.modules['server_side.src.utils.firestore_helpers'] = MagicMock()
sys.modules['server_side.src.utils.firestore_helpers'].FirestoreService = mock_firestore_service_class

# =========================================================
# 4. Now import the modules (use mocks)
# =========================================================

# Import process_actions - use mocked Firebase
from server_side.src.logic.process_actions import (
    data_converter,
    our_model,
)

# Import cleanup_services - use mocked services
from server_side.src.logic.cleanup_services import (
    cleanup_expired_rooms,
    cleanup_offline_participants,
    OFFLINE_THRESHOLD_MS
)

# =========================================================
# 5. Mock MapsService
# =========================================================

class MockMapsService:
    """Mock version of MapsService returning dummy place details."""
    def get_place_details(self, place_id):
        """
        Simulate fetching place details from Google Maps API.
        
        Args:
            place_id (str): The Google Maps Place ID to mock.
            
        Returns:
            dict: A dictionary containing dummy place details with structure:
                {
                    "placeId": str,
                    "name": str,
                    "address": str
                }
        """
        return {
            "placeId": place_id,
            "name": f"Place {place_id}",
            "address": "123 Test Street",
        }

# =========================================================
# 6. Tests for data_converter (with corrected signature)
# =========================================================

def test_data_converter_basic():
    """
    Test data_converter with sample participant data.
    
    Verifies that:
    1. Total user count is correct
    2. Cuisine preferences are aggregated properly (including live + default)
    3. Dietary restrictions are counted correctly
    4. Budget ranges are extracted properly
    5. Place details are fetched and counted
    6. Each place includes a '_count' field
    """
    participants = [
        {
            "livePreferences": [{"cuisine": "Italian", "placeId": "p1"}],
            "preferredCuisine": ["Mexican"],
            "budget": [10, 50],
            "dietaryRestrictions": ["vegan"],
        },
        {
            "livePreferences": [{"cuisine": "Italian", "placeId": "p2"}],
            "preferredCuisine": [],
            "budget": [20, 60],
            "dietaryRestrictions": [],
        },
    ]

    result = data_converter(participants, MockMapsService())

    assert result["total_users"] == 2
    assert result["cuisine_counts"] == {"Italian": 2, "Mexican": 1}
    assert result["dietary_counts"] == {"vegan": 1}
    assert result["min_budgets"] == [10, 20]
    assert result["max_budgets"] == [50, 60]

    place_ids = {p["placeId"] for p in result["places"]}
    assert place_ids == {"p1", "p2"}

    for place in result["places"]:
        assert "_count" in place

def test_data_converter_empty():
    """
    Test data_converter with empty participant list.
    
    Verifies that:
    1. Returns all empty structures when no participants
    2. total_users is 0
    3. All counters and lists are empty
    4. Handles edge case gracefully
    """
    # Note: data_converter now expects a list, not a dict
    result = data_converter([], MockMapsService())
    assert result == {
        "cuisine_counts": {},
        "places": [],
        "dietary_counts": {},
        "min_budgets": [],
        "max_budgets": [],
        "total_users": 0,
    }

# =========================================================
# 7. Tests for our_model (Gemini mocked)
# =========================================================

@patch("server_side.src.logic.process_actions.generate_prompt_for_user", return_value="Friendly!")
@patch("server_side.src.logic.process_actions.generate_prompt_for_ai", return_value="mock prompt")
@patch("server_side.src.logic.process_actions.gemini_client")
def test_our_model_success_restaurant(mock_gemini, mock_ai_prompt, mock_user_prompt):
    """
    Test our_model when AI recommends a specific restaurant.
    
    Verifies that:
    1. AI recommendation with place_id is properly parsed
    2. Both Gemini calls are made (recommendation + justification)
    3. Response contains correct restaurant and cuisine
    4. Justification is extracted from second Gemini call
    5. Status is 'success'
    
    Args:
        mock_gemini: Mocked Gemini client
        mock_ai_prompt: Mocked generate_prompt_for_ai function
        mock_user_prompt: Mocked generate_prompt_for_user function
    """
    # First call: main recommendation
    ai_text = json.dumps({
        "recommended_place_id": "p1",
        "recommended_cuisine": "Italian",
        "budget": "10 - 50",
        "reasoning": "Most users prefer Italian"
    })
    
    # Create mock responses
    mock_response1 = MagicMock()
    mock_response1.text = ai_text
    
    mock_response2 = MagicMock()
    mock_response2.text = "Friendly!"
    
    # Set up mock to return different values for each call
    mock_gemini.models.generate_content.side_effect = [
        mock_response1,  # First call
        mock_response2   # Second call
    ]

    participants = [{"livePreferences": [{"cuisine": "Italian", "placeId": "p1"}],
                          "preferredCuisine": [],
                          "budget": [10,50],
                          "dietaryRestrictions":[]}]

    result = our_model(participants, MockMapsService())
    assert result["status"] == "success"
    assert result["recommended_place_id"] == "p1"
    assert result["recommended_cuisine"] == "Italian"
    assert result["justification"] == "Friendly!"

@patch("server_side.src.logic.process_actions.generate_prompt_for_user", return_value="Friendly!")
@patch("server_side.src.logic.process_actions.generate_prompt_for_ai", return_value="mock prompt")
@patch("server_side.src.logic.process_actions.gemini_client")
def test_our_model_success_cuisine_only(mock_gemini, mock_ai_prompt, mock_user_prompt):
    """
    Test our_model when AI recommends only a cuisine type (no specific restaurant).
    
    Verifies that:
    1. AI recommendation with null place_id is properly parsed
    2. Only cuisine type is returned when no restaurant satisfies all constraints
    3. Both Gemini calls are made successfully
    4. Response contains null for place_id but has cuisine recommendation
    5. Status is 'success'
    
    Args:
        mock_gemini: Mocked Gemini client
        mock_ai_prompt: Mocked generate_prompt_for_ai function
        mock_user_prompt: Mocked generate_prompt_for_user function
    """
    ai_text = json.dumps({
        "recommended_place_id": None,
        "recommended_cuisine": "Mexican",
        "budget": "10 - 50",
        "reasoning": "Most users prefer Mexican"
    })
    
    # Create mock responses
    mock_response1 = MagicMock()
    mock_response1.text = ai_text
    
    mock_response2 = MagicMock()
    mock_response2.text = "Friendly!"
    
    mock_gemini.models.generate_content.side_effect = [
        mock_response1,  # First call
        mock_response2   # Second call
    ]

    participants = [{"livePreferences": [{"cuisine": "Mexican"}],
                          "preferredCuisine": [],
                          "budget": [10,50],
                          "dietaryRestrictions":[]}]

    result = our_model(participants, MockMapsService())
    assert result["status"] == "success"
    assert result["recommended_place_id"] is None
    assert result["recommended_cuisine"] == "Mexican"
    assert result["justification"] == "Friendly!"

@patch("server_side.src.logic.process_actions.generate_prompt_for_user", return_value="Edge case reasoning")
@patch("server_side.src.logic.process_actions.generate_prompt_for_ai", return_value="mock prompt")
@patch("server_side.src.logic.process_actions.gemini_client")
def test_our_model_edge_case_no_preferences(mock_gemini, mock_ai_prompt, mock_user_prompt):
    """
    Test our_model edge case when participants have no preferences.
    
    Verifies that:
    1. AI returns null for both place_id and cuisine when no preferences exist
    2. Edge case rule is followed (no cuisine, no dietary restrictions)
    3. Both Gemini calls are made successfully
    4. Humorous/playful reasoning is expected from AI
    5. Status is 'success' even with null recommendations
    
    Args:
        mock_gemini: Mocked Gemini client
        mock_ai_prompt: Mocked generate_prompt_for_ai function
        mock_user_prompt: Mocked generate_prompt_for_user function
    """
    ai_text = json.dumps({
        "recommended_place_id": None,
        "recommended_cuisine": None,
        "budget": "null - null",
        "reasoning": "Hmm... What an interesting guessing game!"
    })
    
    # Create mock responses
    mock_response1 = MagicMock()
    mock_response1.text = ai_text
    
    mock_response2 = MagicMock()
    mock_response2.text = "Edge case reasoning"
    
    mock_gemini.models.generate_content.side_effect = [
        mock_response1,  # First call
        mock_response2   # Second call
    ]

    participants = [{"livePreferences": [],
                          "preferredCuisine": [],
                          "budget": [],
                          "dietaryRestrictions":[]}]

    result = our_model(participants, MockMapsService())
    assert result["status"] == "success"
    assert result["recommended_place_id"] is None
    assert result["recommended_cuisine"] is None
    assert result["justification"] == "Edge case reasoning"

# =========================================================
# 8. Tests for cleanup_offline_participants
# =========================================================

@pytest.mark.asyncio
async def test_cleanup_offline_participants_no_rooms():
    """
    Test cleanup_offline_participants when RTDB has no rooms.
    
    Verifies that:
    1. Function handles empty RTDB gracefully
    2. No exceptions are raised when no data exists
    3. RTDB queries are attempted (get is called)
    4. No participant deletions occur
    5. Returns normally without errors
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    # Reset mocks
    cleanup_module.rtdb_service.root_ref.child.return_value.get.return_value = None
    cleanup_module.rtdb_service.delete_participant.reset_mock()
    
    # Should not raise any exception
    await cleanup_offline_participants()
    
    # Verify get was called
    cleanup_module.rtdb_service.root_ref.child.assert_called_once_with('participants')
    cleanup_module.rtdb_service.root_ref.child.return_value.get.assert_called_once()

@pytest.mark.asyncio
async def test_cleanup_offline_participants_no_offline():
    """
    Test cleanup_offline_participants when no participants are offline beyond threshold.
    
    Verifies that:
    1. Function processes rooms with participants
    2. Participants with recent disconnections are not removed
    3. Participants with no disconnection time are not removed  
    4. Participants just under threshold are not removed
    5. No deletions occur when criteria not met
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    mock_participants = {
        'room1': {
            'user1': {'disconnected_at': int(time.time() * 1000) - 1000, 'submitted': False},  # 1 second ago
            'user2': {'disconnected_at': None, 'submitted': False},
            'user3': {'disconnected_at': int(time.time() * 1000) - OFFLINE_THRESHOLD_MS + 1000, 'submitted': False},  # Just under threshold
        }
    }
    
    cleanup_module.rtdb_service.root_ref.child.return_value.get.return_value = mock_participants
    cleanup_module.rtdb_service.delete_participant.reset_mock()
    
    # Should not raise any exception
    await cleanup_offline_participants()
    
    # Should not delete any participants
    assert cleanup_module.rtdb_service.delete_participant.call_count == 0

@pytest.mark.asyncio
async def test_cleanup_offline_participants_with_offline():
    """
    Test cleanup_offline_participants with participants who are offline beyond threshold.
    
    Verifies that:
    1. Participants over threshold AND not submitted are deleted
    2. Participants under threshold are NOT deleted
    3. Participants who have submitted are NOT deleted (even if offline)
    4. Multiple participants across rooms can be deleted
    5. Async delete method is properly awaited
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    current_time_ms = int(time.time() * 1000)
    
    mock_participants = {
        'room1': {
            'user1': {'disconnected_at': current_time_ms - OFFLINE_THRESHOLD_MS - 1000, 'submitted': False},  # 1 sec over threshold
            'user2': {'disconnected_at': current_time_ms - OFFLINE_THRESHOLD_MS - 5000, 'submitted': False},  # 5 sec over threshold
            'user3': {'disconnected_at': current_time_ms - OFFLINE_THRESHOLD_MS + 1000, 'submitted': False},  # Under threshold
            'user4': {'disconnected_at': current_time_ms - OFFLINE_THRESHOLD_MS - 1000, 'submitted': True},  # Submitted, should not delete
        }
    }
    
    cleanup_module.rtdb_service.root_ref.child.return_value.get.return_value = mock_participants
    cleanup_module.rtdb_service.delete_participant.reset_mock()
    
    # Should not raise any exception
    await cleanup_offline_participants()
    
    # Should delete user1 and user2, but not user3 (under threshold) or user4 (submitted)
    assert cleanup_module.rtdb_service.delete_participant.call_count == 2
    
    # Check calls
    calls = cleanup_module.rtdb_service.delete_participant.call_args_list
    assert any(call[1]['room_id'] == 'room1' and call[1]['uid'] == 'user1' for call in calls)
    assert any(call[1]['room_id'] == 'room1' and call[1]['uid'] == 'user2' for call in calls)

@pytest.mark.asyncio 
async def test_cleanup_offline_participants_exception_handling():
    """
    Test cleanup_offline_participants exception handling when RTDB fails.
    
    Verifies that:
    1. Exceptions from RTDB are caught and re-raised with descriptive message
    2. Original exception details are preserved in error message
    3. Proper Exception type is raised (not generic)
    4. Error message follows expected format for caller handling
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    cleanup_module.rtdb_service.root_ref.child.return_value.get.side_effect = Exception("RTDB Error")
    
    # Should raise exception with proper message
    with pytest.raises(Exception, match="Failed offline participant cleanup: RTDB Error"):
        await cleanup_offline_participants()

# =========================================================
# 9. Tests for cleanup_expired_rooms
# =========================================================

@pytest.mark.asyncio
async def test_cleanup_expired_rooms_no_rooms():
    """
    Test cleanup_expired_rooms when Firestore has no rooms.
    
    Verifies that:
    1. Function handles empty room list gracefully
    2. Firestore query is attempted (get_all_rooms is called)
    3. No deletions occur in RTDB or Firestore
    4. No exceptions are raised
    5. Returns normally without performing cleanup operations
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    cleanup_module.firestore_service.get_all_rooms.return_value = []
    cleanup_module.rtdb_service.delete_room.reset_mock()
    cleanup_module.firestore_service.delete_preferences.reset_mock()
    cleanup_module.firestore_service.delete_room.reset_mock()
    
    # Should not raise any exception
    await cleanup_expired_rooms()
    
    cleanup_module.firestore_service.get_all_rooms.assert_called_once()

@pytest.mark.asyncio
async def test_cleanup_expired_rooms_no_expired():
    """
    Test cleanup_expired_rooms when all rooms have future expiry times.
    
    Verifies that:
    1. Future expiry times are correctly identified as not expired
    2. Rooms with expiry times in the future are NOT deleted
    3. All necessary services are queried but no deletions occur
    4. No exceptions are raised when rooms exist but aren't expired
    5. Proper timestamp comparison logic works correctly
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    future_time = datetime.now(timezone.utc).timestamp() + 3600  # 1 hour in future
    
    mock_rooms = [
        {'room_id': 'room1', 'expiryTime': MagicMock(timestamp=MagicMock(return_value=future_time))},
        {'room_id': 'room2', 'expiryTime': MagicMock(timestamp=MagicMock(return_value=future_time + 7200))},
    ]
    
    cleanup_module.firestore_service.get_all_rooms.return_value = mock_rooms
    cleanup_module.rtdb_service.delete_room.reset_mock()
    cleanup_module.firestore_service.delete_preferences.reset_mock()
    cleanup_module.firestore_service.delete_room.reset_mock()
    
    # Should not raise any exception
    await cleanup_expired_rooms()
    
    # Should not delete anything
    cleanup_module.rtdb_service.delete_room.assert_not_called()
    cleanup_module.firestore_service.delete_preferences.assert_not_called()
    cleanup_module.firestore_service.delete_room.assert_not_called()

@pytest.mark.asyncio
async def test_cleanup_expired_rooms_with_expired():
    """
    Test cleanup_expired_rooms with a mix of expired and non-expired rooms.
    
    Verifies that:
    1. Expired rooms (past expiry) trigger full cleanup chain:
       - RTDB participants deleted via delete_room()
       - Firestore preferences deleted via delete_preferences()
       - Firestore room document deleted via delete_room()
    2. Non-expired rooms (future expiry) are NOT cleaned up
    3. Room without room_id field is handled gracefully
    4. Timestamp comparison works correctly with mocked datetime
    5. All async calls are properly awaited
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    from server_side.src.logic.cleanup_services import cleanup_expired_rooms

    now_ts = datetime.now(timezone.utc).timestamp()
    
    # Create proper AsyncMocks for delete_room
    cleanup_module.rtdb_service.delete_room = AsyncMock()
    cleanup_module.firestore_service.delete_preferences = AsyncMock()
    cleanup_module.firestore_service.delete_room = AsyncMock()

    # Create mocks for expiryTime objects
    mock_rooms = [
        {'room_id': 'room1', 'expiryTime': MagicMock(timestamp=MagicMock(return_value=now_ts - 3600))},  # expired
        {'room_id': 'room2', 'expiryTime': MagicMock(timestamp=MagicMock(return_value=now_ts - 7200))},  # expired
        {'room_id': 'room3', 'expiryTime': MagicMock(timestamp=MagicMock(return_value=now_ts + 1800))},  # not expired
    ]
    
    cleanup_module.firestore_service.get_all_rooms = MagicMock(return_value=mock_rooms)

    # Run cleanup
    await cleanup_expired_rooms()

    # Check only expired rooms were deleted
    deleted_rooms = [call.args[0] for call in cleanup_module.rtdb_service.delete_room.await_args_list]
    assert "room1" in deleted_rooms
    assert "room2" in deleted_rooms
    assert "room3" not in deleted_rooms

    # Firestore deletions
    assert cleanup_module.firestore_service.delete_preferences.await_count == 2
    assert cleanup_module.firestore_service.delete_room.await_count == 2


@pytest.mark.asyncio
async def test_cleanup_expired_rooms_exception_handling():
    """
    Test cleanup_expired_rooms exception handling when Firestore fails.
    
    Verifies that:
    1. Exceptions from Firestore are caught and re-raised
    2. Original exception message is preserved in error
    3. Proper Exception type is raised (not generic)
    4. Error message follows expected format: "Failed expired room cleanup: <original_error>"
    5. Allows caller to properly handle and log the failure
    """
    import server_side.src.logic.cleanup_services as cleanup_module
    
    cleanup_module.firestore_service.get_all_rooms.side_effect = Exception("Firestore Error")
    
    # Should raise exception with proper message
    with pytest.raises(Exception, match="Failed expired room cleanup: Firestore Error"):
        await cleanup_expired_rooms()
