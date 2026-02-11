###NOT YET TESTED###
import os
import sys
import pytest

# ------------------------------------------------------------------
# Mark this as integration test
# ------------------------------------------------------------------
pytestmark = pytest.mark.integration

# ------------------------------------------------------------------
# Ensure project root on PYTHONPATH
# ------------------------------------------------------------------
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# ------------------------------------------------------------------
# Sanity check: fail fast if env vars missing
# ------------------------------------------------------------------
REQUIRED_ENV_VARS = [
    "GEMINI_API_KEY",
    "GOOGLE_MAPS_API_KEY",
    "FIREBASE_ADMIN_KEY_PATH",
]

for var in REQUIRED_ENV_VARS:
    if not os.getenv(var):
        pytest.skip(f"{var} not set — skipping real API integration test")

# ------------------------------------------------------------------
# Import REAL implementation (no mocks)
# ------------------------------------------------------------------
from server_side.src.logic.process_actions import (
    data_converter,
    our_model,
)

# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------

def test_data_converter_real_environment():
    """
    data_converter should work normally in real environment
    (no external calls here).
    """
    payload = {
        "participants": [
            {
                "uid": "user_1",
                "lat": 3.1390,      # Kuala Lumpur
                "lng": 101.6869
            },
            {
                "uid": "user_2",
                "lat": 3.0738,
                "lng": 101.5183
            },
        ]
    }

    result = data_converter(payload)

    assert isinstance(result, list)
    assert len(result) == 2
    assert "uid" in result[0]


def test_our_model_real_api_calls():
    """
    FULL integration test:
    - Google Maps API
    - Gemini API
    - Firebase Admin SDK
    """
    payload = {
        "participants": [
            {
                "uid": "user_1",
                "lat": 3.1390,
                "lng": 101.6869
            },
            {
                "uid": "user_2",
                "lat": 3.0738,
                "lng": 101.5183
            },
            {
                "uid": "user_3",
                "lat": 3.0827,
                "lng": 101.6501
            },
        ],
        "host_uid": "user_1"
    }

    result = our_model(payload)

    # We don't assert exact values (API-dependent),
    # only that the pipeline succeeds.
    assert result is not None
    assert isinstance(result, dict)

    # Optional sanity checks (adjust to your real schema)
    assert "meeting_point" in result or "result" in result
