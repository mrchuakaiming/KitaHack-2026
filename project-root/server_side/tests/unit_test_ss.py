import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest
import json

# =========================================================
# 0. Environment + path setup (BEFORE any imports)
# =========================================================

os.environ["GEMINI_API_KEY"] = "dummy"
os.environ["GOOGLE_MAPS_API_KEY"] = "dummy"
os.environ["FIREBASE_ADMIN_KEY_PATH"] = "/dummy/path"

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

# =========================================================
# 1. Patch config modules
# =========================================================

mock_main_config = MagicMock()
mock_main_config.GEMINI_API_KEY = "dummy"
mock_main_config.GOOGLE_MAPS_API_KEY = "dummy"
mock_main_config.FIREBASE_ADMIN_KEY_PATH = "/dummy/path"
mock_main_config.MAPS_API_KEY = "dummy"

sys.modules["server_side.src.config"] = mock_main_config
mock_maps_config = MagicMock()
mock_maps_config.GOOGLE_MAPS_API_KEY = "dummy"
sys.modules["config"] = mock_maps_config

# =========================================================
# 2. Patch Firebase
# =========================================================

mock_firestore_client = MagicMock()
firebase_patches = [
    patch("firebase_admin.credentials.Certificate", return_value=MagicMock()),
    patch("firebase_admin.initialize_app", return_value=MagicMock()),
    patch("firebase_admin.firestore.client", return_value=mock_firestore_client),
]
for p in firebase_patches:
    p.start()

# =========================================================
# 3. Patch Gemini modules
# =========================================================

sys.modules["google.genai"] = MagicMock()
sys.modules["google.genai.types"] = MagicMock()

# =========================================================
# 4. Import AFTER all patches
# =========================================================

from server_side.src.logic.process_actions import (
    data_converter,
    our_model,
)

# =========================================================
# 5. Mock MapsService
# =========================================================

class MockMapsService:
    def get_place_details(self, place_id):
        return {
            "placeId": place_id,
            "name": f"Place {place_id}",
            "address": "123 Test Street",
        }

# =========================================================
# 6. Tests for data_converter
# =========================================================

def test_data_converter_basic():
    room_data = {
        "participants": [
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
    }

    result = data_converter(room_data, MockMapsService())

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
    result = data_converter({}, MockMapsService())
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

    room_data = {
        "participants": [{"livePreferences": [{"cuisine": "Italian", "placeId": "p1"}],
                          "preferredCuisine": [],
                          "budget": [10,50],
                          "dietaryRestrictions":[]}]
    }

    result = our_model(room_data, MockMapsService())
    assert result["status"] == "success"
    assert result["recommended_place_id"] == "p1"
    assert result["recommended_cuisine"] == "Italian"
    assert result["justification"] == "Friendly!"  # Now this should pass

@patch("server_side.src.logic.process_actions.generate_prompt_for_user", return_value="Friendly!")
@patch("server_side.src.logic.process_actions.generate_prompt_for_ai", return_value="mock prompt")
@patch("server_side.src.logic.process_actions.gemini_client")
def test_our_model_success_cuisine_only(mock_gemini, mock_ai_prompt, mock_user_prompt):
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

    room_data = {
        "participants": [{"livePreferences": [{"cuisine": "Mexican"}],
                          "preferredCuisine": [],
                          "budget": [10,50],
                          "dietaryRestrictions":[]}]
    }

    result = our_model(room_data, MockMapsService())
    assert result["status"] == "success"
    assert result["recommended_place_id"] is None
    assert result["recommended_cuisine"] == "Mexican"
    assert result["justification"] == "Friendly!"

@patch("server_side.src.logic.process_actions.generate_prompt_for_user", return_value="Edge case reasoning")
@patch("server_side.src.logic.process_actions.generate_prompt_for_ai", return_value="mock prompt")
@patch("server_side.src.logic.process_actions.gemini_client")
def test_our_model_edge_case_no_preferences(mock_gemini, mock_ai_prompt, mock_user_prompt):
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

    room_data = {
        "participants": [{"livePreferences": [],
                          "preferredCuisine": [],
                          "budget": [],
                          "dietaryRestrictions":[]}]
    }

    result = our_model(room_data, MockMapsService())
    assert result["status"] == "success"
    assert result["recommended_place_id"] is None
    assert result["recommended_cuisine"] is None
    assert result["justification"] == "Edge case reasoning"

# =========================================================
# 8. Cleanup
# =========================================================

for p in firebase_patches:
    p.stop()
