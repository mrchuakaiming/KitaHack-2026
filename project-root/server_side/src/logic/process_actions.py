from typing import Any, Dict,List
import os,json, requests
from google.genai import genai, types
import firebase_admin
from firebase_admin import credentials, firestore
from server_side.config import FIREBASE_ADMIN_KEY_PATH, GEMINI_API_KEY, MAPS_API_KEY
from server_side.src.utils.maps_service import MapsService

# -----------------------------------
# API INITIALIZATION
# -----------------------------------
# Firebase Admin SDK
if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_ADMIN_KEY_PATH)
    firebase_admin.initialize_app(cred)
db = firestore.client()

# Gemini AI client (can be re-initialized in functions if needed)
gemini_client = genai.Client(api_key=GEMINI_API_KEY)

# MapsService instance for server-side Google Maps calls
maps_service_instance = MapsService()

# -----------------------------------
# FUNCTION GUIDE / WHEN TO CALL
# -----------------------------------
# 1. data_converter(room_data, maps_service_instance)
#    - Convert raw client participant data to structured format for AI
#    - Fetch place details using MapsService
# 2. generate_prompt_for_ai(ai_payload)
#    - Prepare prompt for Gemini AI
# 3. generate_prompt_for_user(reasoning_sentence)
#    - Enhance AI reasoning for user-friendly message
# 4. our_model(room_data, maps_service_instance)
#    - Main function called by client-side AIService
#    - Returns {"status", "recommended_place_id", "recommended_cuisine", "justification"}

# -----------------------------------
# DATA CONVERSION AND AI LOGIC
# -----------------------------------
def data_converter(room_data: Dict[str, Any], maps_service) -> Dict[str, Any]:
    """
    Convert client-sent (host) room data into AI-readable structure.
    After counting place IDs, replaces each placeId with place data from MapsService.

    Args:
        room_data: {
            "participants": [
                {
                    "livePreferences": [
                        {"cuisine": str, "placeId": str | None}, ...
                    ],
                    "defaultPreferences": [str, ...],
                    "budget": {"min": int | None, "max": int | None},
                    "dietaryRestrictions": [str, ...],
                }, ...
            ]
        }
        maps_service: instance of MapsService for fetching place details.  

    Returns:
        {
            "cuisine_counts": {cuisine: count, ...},
            "places": [full place dicts with _count, ...],
            "dietary_counts": {dietary: count, ...},
            "min_budgets": [int, ...],
            "max_budgets": [int, ...],
            "total_users": int,
        }
    """
    # Extract participants from room data; default to empty list
    participants = room_data.get("participants", [])

    # Return empty structure if no participants
    if not participants:
        return {
            "cuisine_counts": {},
            "places": [],
            "dietary_counts": {},
            "min_budgets": [],
            "max_budgets": [],
            "total_users": 0,
        }

    # Initialize counters and lists
    cuisine_counter: Dict[str, int] = {}     # Counts of each cuisine preference
    place_id_counter: Dict[str, int] = {}    # Counts of each placeId in livePreferences
    dietary_counter: Dict[str, int] = {}     # Counts of dietary restrictions
    min_budgets: List[int] = []              # List of users' min budgets
    max_budgets: List[int] = []              # List of users' max budgets

    # Aggregate data from participants
    for user in participants:
        # Process live preferences (only non-null values)
        for pref in user.get("livePreferences", []):
            cuisine = pref.get("cuisine")
            place_id = pref.get("placeId")

            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1
            if place_id:
                place_id_counter[place_id] = place_id_counter.get(place_id, 0) + 1

        # Process default preferences
        for cuisine in user.get("defaultPreferences", []):
            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1

        # Extract budget info
        budget = user.get("budget", {})
        if "min" in budget and budget["min"] is not None:
            min_budgets.append(budget["min"])
        if "max" in budget and budget["max"] is not None:
            max_budgets.append(budget["max"])

        # Count dietary restrictions
        for diet in user.get("dietaryRestrictions", []):
            if diet:
                dietary_counter[diet] = dietary_counter.get(diet, 0) + 1

    # Replace place IDs with full place details using MapsService
    places: List[Dict[str, Any]] = []
    for place_id in place_id_counter.keys():
        try:
            place_data = maps_service.get_place_details(place_id)
            if place_data:
                # Add the count of users who selected this place
                place_data["_count"] = place_id_counter[place_id]
                places.append(place_data)
        except Exception as e:
            # Log warning if fetching place details fails
            print(f"[WARN] Failed to fetch place {place_id}: {e}")

    # Return structured data ready for AI processing
    return {
        "cuisine_counts": cuisine_counter,
        "places": places,  # Full place dicts instead of just IDs
        "dietary_counts": dietary_counter,
        "min_budgets": min_budgets,
        "max_budgets": max_budgets,
        "total_users": len(participants),
    }

def generate_prompt_for_ai(data: Dict[str, Any]) -> str:
    """
    Generate structured prompt for Gemini AI.

    Args:
        data: {
            "group_preferences": {cuisine: count, ...},
            "restaurants": [full place dicts, ...],
            "budget_range": {"min": list[int], "max": list[int]},
            "dietary_restrictions": [str, ...],
            "total_users": int,
        }

    Returns:
        str: prompt string
    """
    return f"""
You are an AI decision engine for a group dining application.

GROUP PREFERENCES (Cuisine Counts):
{json.dumps(data["group_preferences"], indent=2)}

BUDGET RANGE (GROUP):
{json.dumps(data["budget_range"], indent=2)}

DIETARY RESTRICTIONS:
{json.dumps(data["dietary_restrictions"], indent=2)}

RESTAURANT OPTIONS:
{json.dumps(data["restaurants"], indent=2)}

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

RESPONSE (STRICT JSON):
{{
  "recommended_place_id": "<place_id or null>",
  "recommended_cuisine": "<cuisine or null>",
  "reasoning": "<max 2 sentences>"
}}
"""


def generate_prompt_for_user(reasoning_sentence: str) -> str:
    """
    Enhance AI's reasoning into a lively, convincing justification.

    Args:
        reasoning_sentence: short reasoning from AI output

    Returns:
        str: user-friendly justification (can include emojis or kaomojis)
    """
    try:
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

        prompt = f"""
You are a friendly, expressive assistant for a group dining app.  
Take the following sentence and rewrite it so that it is more lively, convincing, and user-friendly.  
Feel free to add emojis, kaomojis, or expressive language. Keep it concise (max 2 sentences).  
Make it polite, fun, and relatable to the users.  

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
    except Exception as e:
        # Fallback: return original reasoning if AI fails
        return reasoning_sentence

def our_model(room_data: Dict[str, Any], maps_service) -> Dict[str, Any]:
    """
    Core AI decision logic.

    Called by client-side only:
        client → ai_service → our_model

    Args:
        room_data: Raw participant data from client
        maps_service: Instance of MapsService to fetch place details

    Returns:
        {
            "status": "success" | "error",
            "recommended_place_id": str | None,
            "recommended_cuisine": str | None,
            "justification": str
        }
    """
    try:
        # Convert raw room data into AI-readable structure
        converted_data = data_converter(room_data, maps_service)

        # Prepare AI payload
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

        # Generate AI prompt
        prompt = generate_prompt_for_ai(ai_payload)

        # Call Gemini AI
        response = gemini_client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )

        # Parse AI response
        result = json.loads(response.text)

        # Enhance justification sentence
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