from typing import Any, Dict, List
import os
import json
from google.genai import genai, types
import firebase_admin
from firebase_admin import credentials, firestore
from server_side.src.config import FIREBASE_ADMIN_KEY_PATH, GEMINI_API_KEY
from server_side.src.utils.maps_service import MapsService

# -----------------------------------
# API INITIALIZATION
# -----------------------------------
# Firebase Admin SDK
if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_ADMIN_KEY_PATH)
    firebase_admin.initialize_app(cred)
db = firestore.client()

# Gemini AI client
gemini_client = genai.Client(api_key=GEMINI_API_KEY)

# MapsService instance (server-side)
maps_service_instance = MapsService()

# -----------------------------------
# DATA CONVERSION AND AI LOGIC
# -----------------------------------
def data_converter(room_data: Dict[str, Any], maps_service) -> Dict[str, Any]:
    """
    Convert client-sent room data into AI-readable structure.
    Replaces each placeId with full place details from MapsService.

    Args:
        room_data (Dict[str, Any]): Room data from Firestore.
        maps_service: Instance of MapsService for fetching place details.

    Returns:
        Dict[str, Any]: Converted data with counts and place details.
    """
    participants = room_data.get("participants", [])
    if not participants:
        return {
            "cuisine_counts": {},
            "places": [],
            "dietary_counts": {},
            "min_budgets": [],
            "max_budgets": [],
            "total_users": 0,
        }

    cuisine_counter: Dict[str, int] = {}
    place_id_counter: Dict[str, int] = {}
    dietary_counter: Dict[str, int] = {}
    min_budgets: List[int] = []
    max_budgets: List[int] = []

    for user in participants:
        for pref in user.get("livePreferences", []):
            cuisine = pref.get("cuisine")
            place_id = pref.get("placeId")
            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1
            if place_id:
                place_id_counter[place_id] = place_id_counter.get(place_id, 0) + 1
        for cuisine in user.get("defaultPreferences", []):
            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1
        budget = user.get("budget", {})
        if "min" in budget and budget["min"] is not None:
            min_budgets.append(budget["min"])
        if "max" in budget and budget["max"] is not None:
            max_budgets.append(budget["max"])
        for diet in user.get("dietaryRestrictions", []):
            if diet:
                dietary_counter[diet] = dietary_counter.get(diet, 0) + 1

    # Replace place IDs with full details
    places: List[Dict[str, Any]] = []
    for place_id in place_id_counter.keys():
        try:
            place_data = maps_service.get_place_details(place_id)
            if place_data:
                place_data["_count"] = place_id_counter[place_id]
                places.append(place_data)
        except Exception as e:
            print(f"[WARN] Failed to fetch place {place_id}: {e}")

    return {
        "cuisine_counts": cuisine_counter,
        "places": places,
        "dietary_counts": dietary_counter,
        "min_budgets": min_budgets,
        "max_budgets": max_budgets,
        "total_users": len(participants),
    }

def generate_prompt_for_ai(data: Dict[str, Any]) -> str:
    """
    Generate strict JSON prompt for Gemini AI.

    Args:
        data (Dict[str, Any]): Converted room data for AI.

    Returns:        
        str: Prompt string for AI model.
    """
    return f"""
You are an AI decision engine for a group dining app.

GROUP PREFERENCES:
{json.dumps(data["group_preferences"], indent=2)}

BUDGET RANGE:
{json.dumps(data["budget_range"], indent=2)}

DIETARY RESTRICTIONS:
{json.dumps(data["dietary_restrictions"], indent=2)}

RESTAURANT OPTIONS:
{json.dumps(data["restaurants"], indent=2)}

TASK:
- Recommend ONE best restaurant or cuisine type.
- Strictly respect dietary restrictions.
- Only return place_id if recommending a specific restaurant; else null.
- If no preferences or dietary restrictions, return nulls and a humorous message.
- Max 2 sentences reasoning.
- STRICT JSON output:

{{
  "recommended_place_id": "<place_id or null>",
  "recommended_cuisine": "<cuisine or null>",
  "reasoning": "<max 2 sentences>"
}}
"""

def generate_prompt_for_user(reasoning_sentence: str) -> str:
    """
    Enhance AI reasoning for user-friendly display.

    Args:
        reasoning_sentence (str): Original AI reasoning.

    Returns:
        str: Enhanced reasoning.
    """
    try:
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        prompt = f"""
You are a friendly assistant. Rewrite the following sentence to be lively, polite, and concise (max 2 sentences).
Original sentence: "{reasoning_sentence}"
"""
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="text/plain",
                temperature=0.5,
            ),
        )
        return response.text.strip()
    except Exception:
        return reasoning_sentence

def our_model(room_data: Dict[str, Any], maps_service) -> Dict[str, Any]:
    """
    Core AI decision logic called by client-side AIService.
    
    Args:
        room_data (Dict[str, Any]): Room data from Firestore.
        maps_service: Instance of MapsService for fetching place details.

    Returns:
        Dict[str, Any]: AI recommendation result.
    """
    try:
        converted_data = data_converter(room_data, maps_service)
        ai_payload = {
            "group_preferences": converted_data.get("cuisine_counts", {}),
            "restaurants": converted_data.get("places", []),
            "budget_range": {
                "min": converted_data.get("min_budgets", []),
                "max": converted_data.get("max_budgets", []),
            },
            "dietary_restrictions": list(converted_data.get("dietary_counts", {}).keys()),
            "total_users": converted_data.get("total_users", 0),
        }

        prompt = generate_prompt_for_ai(ai_payload)
        response = gemini_client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )

        result = json.loads(response.text)
        justification = generate_prompt_for_user(result.get("reasoning", ""))

        return {
            "status": "success",
            "recommended_place_id": result.get("recommended_place_id"),
            "recommended_cuisine": result.get("recommended_cuisine"),
            "justification": justification,
        }

    except Exception as e:
        return {
            "status": "error",
            "recommended_place_id": None,
            "recommended_cuisine": None,
            "justification": f"AI failure: {str(e)}",
        }
