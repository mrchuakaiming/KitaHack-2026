# CHANGED
import requests
from src.config import GOOGLE_MAPS_API_KEY

class MapsService:
    def __init__(self):
        self.api_key = GOOGLE_MAPS_API_KEY
        self.base_url = "https://maps.googleapis.com/maps/api/place"

    def get_place_details(self, place_id: str) -> dict:
        """Fetches restaurant details from Google Maps API."""
        if not self.api_key:
            return None
            
        url = f"{self.base_url}/details/json?place_id={place_id}&key={self.api_key}"
        try:
            response = requests.get(url)
            data = response.json()
            if data.get("status") == "OK":
                result = data["result"]
                return {
                    "name": result.get("name"),
                    "place_id": place_id,
                    "lat": result["geometry"]["location"]["lat"],
                    "lng": result["geometry"]["location"]["lng"],
                    "rating": result.get("rating")
                }
        except Exception as e:
            print(f"🔥 Maps API Error: {e}")
        return None

    def search_places(self, query: str) -> list:
        """Searches for places based on a string query."""
        
        # Physically force the string to look inside Malaysia
        strict_query = f"{query} in Malaysia"
        
        url = f"{self.base_url}/textsearch/json?query={strict_query}&region=my&key={self.api_key}"
        try:
            response = requests.get(url)
            data = response.json()
            return data.get("results", [])
        except Exception as e:
            print(f"🔥 Maps Search Error: {e}")
            return []