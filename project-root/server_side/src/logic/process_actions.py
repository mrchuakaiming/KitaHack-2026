from typing import Any, Dict, List
import os
import json
from google.genai import genai, types
import firebase_admin
from firebase_admin import credentials, firestore
from ...src.config import FIREBASE_ADMIN_KEY_PATH, GEMINI_API_KEY
from ...src.utils.maps_service import MapsService

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

    - Aggregates cuisine preferences (live + default)
    - Aggregates dietary restrictions
    - Aggregates budgets
    - Replaces valid placeIds with full place details via MapsService
    - Silently skips invalid / unfetchable placeIds

    Args:
        room_data (Dict[str, Any]): A list of PreferencesModel from client_side.
        maps_service: Instance of MapsService.

    Returns:
        Dict[str, Any]: Aggregated, AI-ready preference data.
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
        # ----- LIVE PREFERENCES -----
        for pref in user.get("livePreferences", []):
            cuisine = pref.get("cuisine")
            place_id = pref.get("placeId")

            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1

            if place_id:
                place_id_counter[place_id] = place_id_counter.get(place_id, 0) + 1

        # ----- DEFAULT CUISINE -----
        for cuisine in user.get("preferredCuisine", []):
            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1

        # ----- BUDGET -----
        budget = user.get("budget", [])
        if len(budget) >= 1 and budget[0] is not None:
            min_budgets.append(budget[0])
        if len(budget) >= 2 and budget[1] is not None:
            max_budgets.append(budget[1])

        # ----- DIETARY -----
        for diet in user.get("dietaryRestrictions", []):
            if diet:
                dietary_counter[diet] = dietary_counter.get(diet, 0) + 1

    # ----- FETCH PLACE DETAILS -----
    places: List[Dict[str, Any]] = []
    for place_id, count in place_id_counter.items():
        place_data = maps_service.get_place_details(place_id)
        if place_data:
            place_data["_count"] = count
            places.append(place_data)

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
{json.dumps(data["cuisine_counts"], indent=2)}

RESTAURANT OPTIONS:
{json.dumps(data["places"], indent=2)}

BUDGET RANGE:
minimum budgets:
{json.dumps(data["min_budgets"], indent=2)}
maximum budgets:
{json.dumps(data["max_budgets"], indent=2)}

DIETARY RESTRICTIONS:
{json.dumps(data["dietary_counts"], indent=2)}

TOTAL USERS:
{json.dumps(data["total_users"], indent=2)}

TASK:
- Recommend ONE best restaurant or cuisine type.
- Respect dietary restrictions strictly (Priotise this!!!).
- Choose the only one cuisine type or restaurant that maximises group satisfaction. 
(Do not only recommend restaurant if a cuisine type can satisfy more users.)
- Only return the place id if recommending a specific restaurant. !!!Do not return a different place id!!!
- If recommending a cuisine type, return null for place id.
- If there is a restaurant that satisfies the most of the cuisines choices and dietary restrictions, recommend that restaurant.
- Ensure budget compatibility where possible.
- Generate a convincing and reasonable justification for the recommendation.
- Keep it concise, max 2 sentences.
- Explain why this restaurant or cuisine satisfies the group's preferences, dietary restrictions, and budget.
- **Edge case rule**: If there are no cuisine preferences and no dietary restrictions (even if budget exists), leave "recommended_place_id" and "recommended_cuisine" as null!!!  
  In this case, return a !!!polite!!!, !!!humorous!!! message in the reasoning, 
  e.g., "Hmm... What an interesting guessing game!", "It seems like you didn't choose anything, I’m going to have to improvise!", or "Are you kidding me? Let’s eat something fun!".  
  !!Do not use the yellow face emojis!!!
- Respond in STRICT JSON format as shown below.
- STRICT JSON output:

{{
  "recommended_place_id": "<place_id or null>",
  "recommended_cuisine": "<cuisine or null>",
  "budget": "<min> - <max>",
  "reasoning": "<max 2 sentences>"
}}
"""

def generate_prompt_for_user(reasoning_sentence: str) -> str:
    """
    Enhance AI reasoning for user-friendly display.

    Args:
        reasoning_sentence (str): Original AI reasoning.

    Returns:
        str: Prompt for AI to enhanced reasoning.
    """
    return f"""
You are a friendly assistant. Rewrite the following sentence to be lively, polite, and concise (max 2 sentences).
Original sentence: "{reasoning_sentence}"
"""

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

        prompt = generate_prompt_for_ai(converted_data)
        response = gemini_client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )

        result = json.loads(response.text)
        prompt_user = generate_prompt_for_user(result.get("reasoning", ""))

        justification = gemini_client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt_user,
            config=types.GenerateContentConfig(
                response_mime_type="text/plain",
                temperature=0.2,
            ),
        )
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
