# CHANGED
import os
import json
import re
from typing import List, Dict, Any
from google import genai
from google.genai import types
from dotenv import load_dotenv

# --- 1. SETUP ---
# Load environment variables
load_dotenv()

# REMOVED GLOBAL CLIENT INIT to prevent deployment crashes
# client = genai.Client(api_key=GEMINI_API_KEY) <--- GONE

class MockMapsService:
    """
    A placeholder class to mimic the Google Maps Service.
    """
    def get_details(self, place_id): 
        return {}
    
    def search_place(self, query): 
        return []

# Export instance for main.py import compatibility
maps_service_instance = MockMapsService()

def clean_json(text: str) -> str:
    """
    Sanitizes the AI response string to ensure it is valid JSON.
    """
    cleaned = re.sub(r"```json\s*", "", text) # Remove opening tag
    cleaned = re.sub(r"```", "", cleaned)      # Remove closing tag
    return cleaned.strip()

# --- 2. DATA CONVERTER ---
def data_converter(participants: List[Dict[str, Any]]) -> str:
    """
    Converts a list of raw Firestore participant documents into a prompt-ready string.
    """
    formatted_data = []
    
    if not participants:
        return "No participants found."

    for i, p in enumerate(participants):
        # Extract UID
        uid = str(p.get("uid", f"User_{i}"))[:5]
        
        cuisines = set()
        dietary = set()

        # --- A. Extract Cuisines ---
        for key in ["preferred_cuisine", "preferredCuisine"]:
            val = p.get(key)
            if isinstance(val, list):
                cuisines.update([str(c) for c in val])

        live_prefs = p.get("livePreferences", []) or p.get("live_preferences", [])
        if isinstance(live_prefs, list):
            for item in live_prefs:
                if isinstance(item, dict):
                    val = item.get("value") or item.get("cuisine")
                    if val:
                        cuisines.add(str(val))

        # --- B. Extract Dietary Restrictions ---
        for key in ["dietary_restrictions", "dietaryRestrictions"]:
            val = p.get(key)
            if isinstance(val, list):
                dietary.update([str(d) for d in val])

        # --- BUDGET EXTRACTION ---
        # Logic: Extract [min, max] list sent from Flutter
        budget_str = "Flexible"
        raw_budget = p.get("budget")
        if isinstance(raw_budget, list) and len(raw_budget) >= 2:
            budget_str = f"${raw_budget[0]} - ${raw_budget[1]}"

        # Format the line
        user_line = (
            f"- User {uid}: "
            f"Wants [{', '.join(cuisines) if cuisines else 'Anything'}]. "
            f"Dietary [{', '.join(dietary) if dietary else 'None'}]. "
            f"Budget Range: {budget_str}"
        )
        formatted_data.append(user_line)

    final_text = "\n".join(formatted_data)
    
    # Debug Log
    print("\n" + "!"*40)
    print("AI PROMPT DATA CONTEXT:")
    print(final_text)
    print("!"*40 + "\n")
    
    return final_text

# --- 3. MAIN MODEL FUNCTION ---
def our_model(participants: list, maps_service=None) -> Dict[str, Any]:
    """
    Main logic to call Gemini.
    """
    
    # --- LAZY INITIALIZATION (Fixes Deployment Crash) ---
    # We initialize the client HERE, so it only runs when needed.
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
    if not GEMINI_API_KEY:
        print("🔥 Error: GEMINI_API_KEY not found in environment variables.")
        return {
            "recommended_place_id": None, 
            "reasoning": "Server configuration error: Missing AI Key.",
            "budget": "N/A"
        }

    client = genai.Client(api_key=GEMINI_API_KEY)

    context_text = data_converter(participants)
    
    prompt = f"""
    TASK:
    - Recommend ONE best restaurant or cuisine type.
    - Respect dietary restrictions strictly (Prioritise this!!!).
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

    GROUP DATA:
    {context_text}

    - Respond in STRICT JSON format as shown below.
    - STRICT JSON output:

    {{
    "recommended_place_id": "<place_id or null>",
    "recommended_cuisine": "<cuisine or null>",
    "budget": "<min or null> - <max or null>",
    "reasoning": "<max 2 sentences>"
    }}
    """

    try:
        # Call Gemini (Ensure model name is correct for your SDK version)
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1, 
            ),
        )
        return json.loads(clean_json(response.text))
        
    except Exception as e:
        print(f"🔥 Gemini Error: {e}")
        return {
            "recommended_place_id": "Selection Error",
            "recommended_cuisine": "None",
            "reasoning": "The AI encountered a network or quota error.",
            "budget": "N/A"
        }