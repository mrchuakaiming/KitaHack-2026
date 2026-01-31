from typing import Any, Dict, Optional
import os
import json
from google.genai import genai, types

def data_converter(room_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert client-sent room data into AI-readable structure.

    Input schema (from client):
    {
        "roomId": str,
        "participants": [
            {
                "defaultPreference": [str],
                "livePreference": [
                    { "cuisine": str, "placeId": str }
                ],
                "budget": { "min": int, "max": int },
                "dietaryRestrictions": [str]
            }
        ]
    }

    Returns:
        dict: Normalised data for AI model.
    """

    participants = room_data.get("participants", [])

    if not participants:
        return {
            "group_preferences": {},
            "place_ids": [],
            "budget_range": None,
            "dietary_restrictions": [],
            "total_users": 0,
        }

    cuisine_counter = {}
    place_ids = []
    min_budgets = []
    max_budgets = []
    dietary_set = set()

    for user in participants:
        # Live preferences (highest priority)
        for pref in user.get("livePreference", []):
            cuisine = pref.get("cuisine")
            place_id = pref.get("placeId")

            if cuisine:
                cuisine_counter[cuisine] = cuisine_counter.get(cuisine, 0) + 1
            if place_id:
                place_ids.append(place_id)

        # Budget aggregation
        budget = user.get("budget", {})
        if "min" in budget:
            min_budgets.append(budget["min"])
        if "max" in budget:
            max_budgets.append(budget["max"])

        # Dietary aggregation
        dietary_set.update(user.get("dietaryRestrictions", []))

    return {
        "group_preferences": {
            "cuisine_counts": cuisine_counter,
        },
        "place_ids": list(set(place_ids)),  # deduplicated
        "budget_range": {
            "min": min(min_budgets) if min_budgets else None,
            "max": max(max_budgets) if max_budgets else None,
        },
        "dietary_restrictions": list(dietary_set),
        "total_users": len(participants),
    }

def our_model(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Core AI decision logic.

    Called by:
        route → data_converter → our_model
    """

    enriched_restaurants = []

    for pid in data.get("place_ids", []):
        try:
            enriched_restaurants.append(get_place_details(pid))
        except Exception as e:
            print(f"[WARN] Failed to fetch place {pid}: {e}")

    ai_payload = {
        "group_preferences": data["group_preferences"],
        "restaurants": enriched_restaurants,
        "budget_range": data["budget_range"],
        "dietary_restrictions": data["dietary_restrictions"],
        "total_users": data["total_users"],
    }

    prompt = generate_prompt_for_ai(ai_payload)

    try:
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )

        result = json.loads(response.text)

        return {
            "status": "success",
            "recommended_place_id": result.get("recommended_place_id"),
            "recommended_cuisine": result.get("recommended_cuisine"),
            "reasoning": result.get("reasoning", ""),
        }

    except Exception as e:
        return {
            "status": "error",
            "recommended_place_id": None,
            "recommended_cuisine": None,
            "reasoning": f"AI failure: {str(e)}",
        }

def generate_prompt_for_ai(data: Dict[str, Any]) -> str:
    """
    Generate structured prompt for Gemini AI.
    """

    return f"""
You are an AI decision engine for a group dining application.

GROUP SIZE:
{data["total_users"]}

GROUP PREFERENCES:
{json.dumps(data["group_preferences"], indent=2)}

BUDGET RANGE (GROUP):
{json.dumps(data["budget_range"], indent=2)}

DIETARY RESTRICTIONS:
{json.dumps(data["dietary_restrictions"], indent=2)}

RESTAURANT OPTIONS:
{json.dumps(data["restaurants"], indent=2)}

TASK:
- Recommend ONE best restaurant.
- If no restaurant fits, recommend only a cuisine type.
- Respect dietary restrictions strictly.
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
    restaurant: Optional[Dict[str, Any]],
    total_users: int,
) -> str:
    """
    Convert AI result into user-facing explanation.
    """

    if ai_result.get("status") != "success":
        return "We couldn’t reach a group decision this time. Please try again."

    if restaurant:
        name = restaurant.get("name", "this restaurant")
        return (
            f"🍽️ **{name}** was chosen for your group of {total_users}. "
            f"{ai_result.get('reasoning', '')}"
        )

    return (
        f"🍽️ A **{ai_result.get('recommended_cuisine')}** cuisine was chosen "
        f"as the best match for your group of {total_users}. "
        f"{ai_result.get('reasoning', '')}"
    )

