from typing import Any, Dict, Optional
import os
import json
from google.genai import genai, types

from typing import Any, Dict, List
import json

# Assume MapsService exists and is imported
# from maps_service import MapsService

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


def our_model(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Core AI decision logic.

    Called by:
        route → data_converter → our_model

    Args:
        data: output from data_converter

    Returns:
        {
            "status": "success" | "error",
            "recommended_place_id": str | None,
            "recommended_cuisine": str | None,
            "reasoning": str
        }
    """
# Prepare payload for AI from pre-processed data
    ai_payload = {
        "group_preferences": data.get("cuisine_counts", {}),
        "restaurants": data.get("places", []),  # Already enriched by data_converter
        "budget_range": {
            "min": min(data.get("min_budgets", [])) if data.get("min_budgets") else None,
            "max": max(data.get("max_budgets", [])) if data.get("max_budgets") else None,
        },
        "dietary_restrictions": list(data.get("dietary_counts", {}).keys()),
        "total_users": data.get("total_users", 0),
    }

    # Generate AI prompt using structured payload
    prompt = generate_prompt_for_ai(ai_payload)

    try:
        # Initialize Gemini AI client using API key from environment
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

        # Call AI model to generate recommendation
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,  # low randomness for consistent results
            ),
        )

        # Parse JSON response from AI
        result = json.loads(response.text)

        # Return structured AI recommendation
        return {
            "status": "success",
            "recommended_place_id": result.get("recommended_place_id"),
            "recommended_cuisine": result.get("recommended_cuisine"),
            "reasoning": result.get("reasoning", ""),
        }

    except Exception as e:
        # Handle AI errors gracefully
        return {
            "status": "error",
            "recommended_place_id": None,
            "recommended_cuisine": None,
            "reasoning": f"AI failure: {str(e)}",
        }


def generate_prompt_for_ai(data: Dict[str, Any]) -> str:
    """
    Generate structured prompt for Gemini AI.

    Args:
        data: {
            "group_preferences": {cuisine: count, ...},
            "restaurants": [full place dicts, ...],
            "budget_range": {"min": int | None, "max": int | None},
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
- Chose the only one cuisine type or restaurant that maximizes group satisfaction. 
(Do not only recommend restaurant if a cuisine type can satisfy more users.)
- Only return the place id if recommending a specific restaurant. !!!Do not return a different place id!!!
- If recommending a cuisine type, return null for place id.
- If there is a restaurant that satisfies the most of the cuisines choices and dietary restrictions, recommend that restaurant.
- Ensure budget compatibility where possible.

RESPONSE (STRICT JSON):
{{
  "recommended_place_id": "<place_id or null>",
  "recommended_cuisine": "<cuisine or null>",
  "reasoning": "<max 2 sentences>"
}}
"""


def generate_prompt_for_user(
    ai_result: Dict[str, Any],
    restaurants: Optional[list],
) -> Dict[str, Any]:
    """
    Convert AI result into a user-friendly dictionary.
    Args:
        ai_result: output from our_model
        restaurants: list of full restaurant dicts from data_converter
    Returns:
        {
            "recommended": dict | str,  # full restaurant dict or cuisine type
            "budget": dict | None,      # min/max if available
            "justification": str
        }
    """

    if ai_result.get("status") != "success":
        return {
            "recommended": None,
            "budget": None,
            "justification": "We couldn’t reach a group decision this time. Please try again."
        }

    # Extract AI recommendation details
    recommended_place_id = ai_result.get("recommended_place_id")
    recommended_cuisine = ai_result.get("recommended_cuisine")
    reasoning = ai_result.get("reasoning", "")

    recommended = None
    budget = None

    if recommended_place_id and restaurants:
        # Find the full restaurant dictionary matching the recommended ID
        recommended = next(
            (r for r in restaurants if r.get("place_id") == recommended_place_id),
            None
        )
        if recommended:
            # Extract min/max budget for display
            budget = {
                "min": recommended.get("price_level_min"),
                "max": recommended.get("price_level_max")
            }
    elif recommended_cuisine:
        # If no specific place, recommend a cuisine type
        recommended = recommended_cuisine
        budget = None

    # Return user-friendly recommendation
    return {
        "recommended": recommended,
        "budget": budget,
        "justification": reasoning
    }

def generate_recommendation(room_data: Dict[str, Any], maps_service) -> Dict[str, Any]:
    """
    Orchestrates the full process of generating a group dining recommendation.

    Steps:
    1. Convert raw client data into AI-readable structure (data_converter)
    2. Call AI model to get recommendation (our_model)
    3. Format AI result into user-friendly output (generate_prompt_for_user)

    Args:
        room_data: Raw room data sent by client
        maps_service: Instance of MapsService to fetch place details

    Returns:
        Dict with user-friendly recommendation:
        {
            "recommended": dict | str | None,  # full restaurant dict or cuisine type
            "budget": dict | None,              # min/max if available
            "justification": str
        }
    """

    #Convert client data into structured AI input
    converted_data = data_converter(room_data, maps_service)

    #Get AI recommendation based on converted data
    ai_result = our_model(converted_data)

    #Generate user-friendly recommendation
    user_friendly_result = generate_prompt_for_user(
        ai_result=ai_result,
        restaurants=converted_data.get("places", []),
        total_users=converted_data.get("total_users", 0)
    )

    return user_friendly_result
