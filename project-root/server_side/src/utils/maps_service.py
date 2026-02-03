"""
MapsService (Server-Side)

Handles all secure Google Maps API requests using the server-side API key.
Client-side never sees the API key.

-----------------------------------
FUNCTION GUIDE / USAGE
-----------------------------------
1. Get place details (used by AI recommendation):
    maps_service.get_place_details(place_id)
    - Returns a dictionary with:
        { "name": str, "lat": float, "lng": float, "place_id": str }

2. Search for restaurants (optional, server-side only):
    maps_service.search_places(query, location=None, radius=1000)
    - Returns a list of dictionaries with:
        { "name": str, "place_id": str, "lat": float, "lng": float }

-----------------------------------
NOTES
-----------------------------------
- All calls use the server API key stored in environment variable:
    GOOGLE_MAPS_API_KEY
- Handles errors gracefully and logs warnings.
- For client-side user searches, use Maps JS SDK in the browser.
"""
import requests
from config import GOOGLE_MAPS_API_KEY

class MapsService:
    def __init__(self, api_key: str = None):
        self.api_key = api_key or GOOGLE_MAPS_API_KEY
        if not self.api_key:
            raise ValueError("Google Maps API key not found in environment variables.")

    # ----------------------------
    # GET PLACE DETAILS
    # ----------------------------
    def get_place_details(self, place_id: str) -> dict:
        """
        Fetch place details using Google Maps Place Details API.

        Args:
            place_id (str): The Google Maps Place ID

        Returns:
            dict: {
                "place_id": str,
                "name": str,
                "lat": float,
                "lng": float
            }
        """
        url = "https://maps.googleapis.com/maps/api/place/details/json"
        params = {
            "place_id": place_id,
            "key": self.api_key,
            "fields": "name,geometry"
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            if data.get("status") != "OK":
                print(f"[WARN] Place Details API returned {data.get('status')} for {place_id}")
                return {}

            result = data.get("result", {})
            location = result.get("geometry", {}).get("location", {})
            return {
                "place_id": place_id,
                "name": result.get("name", ""),
                "lat": location.get("lat"),
                "lng": location.get("lng"),
            }

        except Exception as e:
            print(f"[ERROR] Failed to get place details for {place_id}: {e}")
            return {}

    # ----------------------------
    # SEARCH PLACES (OPTIONAL)
    # ----------------------------
    def search_places(self, query: str, location: str = None, radius: int = 1000) -> list:
        """
        Search for places (e.g., restaurants) using Google Maps Text Search API.
        Optional server-side search if needed (AI or admin logic).

        Args:
            query (str): Search query (e.g., "sushi restaurant")
            location (str): "lat,lng" optional for nearby search
            radius (int): Search radius in meters

        Returns:
            list of dict: [
                { "name": str, "place_id": str, "lat": float, "lng": float }, ...
            ]
        """
        url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        params = {
            "query": query,
            "key": self.api_key,
        }
        if location:
            params["location"] = location
            params["radius"] = radius

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            if data.get("status") != "OK":
                print(f"[WARN] Places Text Search API returned {data.get('status')} for query '{query}'")
                return []

            results = []
            for r in data.get("results", []):
                loc = r.get("geometry", {}).get("location", {})
                results.append({
                    "name": r.get("name", ""),
                    "place_id": r.get("place_id", ""),
                    "lat": loc.get("lat"),
                    "lng": loc.get("lng"),
                })
            return results

        except Exception as e:
            print(f"[ERROR] Failed to search places for query '{query}': {e}")
            return []
