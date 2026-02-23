# CHANGED
import os
import sys
import json
import requests  # Required for proxying requests to Google Maps
import firebase_admin
from firebase_functions import https_fn, options
from firebase_admin import initialize_app, firestore, db as rtdb
from dotenv import load_dotenv
from google.cloud.firestore_v1.base_query import FieldFilter

# --- 1. Path & Environment Setup ---
# Ensure the logic module in the src directory is discoverable by Python
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

# Initialize Firebase Admin SDK (Safe at top level if wrapped)
if not firebase_admin._apps:
    initialize_app(options={
        'databaseURL': 'https://what2eat-1469f-default-rtdb.asia-southeast1.firebasedatabase.app'
    })

# Load environment variables from .env (Only for local dev; ignored in Cloud if not included in deploy)
load_dotenv()

# --- 2. Logic Imports ---
from src.logic.process_actions import our_model, maps_service_instance
# [NEW] Import the cleanup logic functions
from src.logic.cleanup_services import cleanup_expired_rooms, cleanup_offline_participants

# ==================================================================================
# CLOUD FUNCTION CONFIGURATION
# ==================================================================================
# We use the decorator to handle CORS automatically. 
# cors_origins="*" tells Firebase to inject the 'Access-Control-Allow-Origin' header
# into every response. We do NOT need to add it manually inside the function.
@https_fn.on_request(
    memory=options.MemoryOption.MB_512, 
    region="asia-southeast1",
    secrets=["GOOGLE_MAPS_API_KEY"],  # securely injects the key from Secret Manager
    cors=options.CorsOptions(
        cors_origins="*",  # Automatically handles CORS for all domains
        cors_methods=["get", "post", "options"], # Allowed HTTP methods
    )
)
def api(req: https_fn.Request) -> https_fn.Response:
    """
    Main entry point for the What2Eat Backend API.
    
    Routes:
    - /search: Proxies requests to Google Places API to avoid exposing keys on the client.
    - /ai/generate-outcome: Aggregates user preferences and uses Gemini to pick a winner.
    """
    
    # --- LAZY INITIALIZATION ---
    # We initialize Firestore ONLY when a request actually comes in to prevent 
    # cold-start crashes if the global scope fails.
    firestore_client = firestore.client()

    # NOTE: We have REMOVED the manual 'headers' dictionary and the 'OPTIONS' check.
    # The decorator above handles all Preflight (OPTIONS) requests automatically.

    try:
        # Normalize the path for routing (removes leading/trailing slashes)
        path = req.path.strip("/")
        
        # =====================================================================
        # ROUTE 1: /search
        # Purpose: Proxies Google Maps Text Search to hide the API Key
        # =====================================================================
        if "search" in path:
            # Parse JSON body safely
            data = req.get_json(silent=True)
            query = data.get("query") if data else None
            
            if not query:
                return https_fn.Response("Missing 'query' parameter", status=400)

            # Retrieve key from Secrets (Prod) or .env (Local)
            google_maps_key = os.environ.get("GOOGLE_MAPS_API_KEY")
            
            if not google_maps_key:
                print("🔥 Configuration Error: GOOGLE_MAPS_API_KEY is missing")
                return https_fn.Response("Internal Server Error: API Key missing", status=500)

            # Construct call to Google Places Text Search
            url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
            params = {
                "query": query,
                "key": google_maps_key
            }
            
            print(f"🔎 Proxying Search Request for: {query}")
            
            # Make the actual request to Google (Server-to-Server)
            response = requests.get(url, params=params)
            
            # Return the raw Google Maps JSON back to Flutter
            # NOTE: We do NOT pass 'headers=' here. The decorator adds them.
            return https_fn.Response(
                response.text,
                status=response.status_code,
                mimetype="application/json"
            )

        # =====================================================================
        # ROUTE 2: /ai/generate-outcome
        # Purpose: Triggers the Gemini decision logic
        # =====================================================================
        if "ai/generate-outcome" in path:
            data = req.get_json(silent=True)
            if not data:
                return https_fn.Response("Missing JSON body", status=400)
            
            room_id = data.get("roomId")
            if not room_id:
                return https_fn.Response("Missing 'roomId'", status=400)

            print(f"🔍 Fetching preferences for room: {room_id}")
            
            # Step 1: Fetch user preferences specifically for this room from Firestore
            prefs_ref = firestore_client.collection("preferences")
            query = prefs_ref.where(filter=FieldFilter("room_id", "==", room_id))
            docs = query.stream()

            participants = []
            for doc in docs:
                p_data = doc.to_dict()
                participants.append(p_data)
                print(f"   - Found participant: {p_data.get('uid', 'Unknown')[:5]}...")

            # Fallback to request body if Firestore is empty (for testing)
            if not participants:
                print("⚠️ No Firestore docs found. Using request body participants.")
                participants = data.get("participants", [])

            # Step 2: Set room status to 'processing' so UI shows a loading state
            doc_ref = firestore_client.collection("rooms").document(room_id)
            doc_ref.update({"status": "processing"})

            # Step 3: Call the logic module (Gemini)
            print(f"🧠 Running Gemini recommendation for {len(participants)} users...")
            ai_result = our_model(participants, maps_service_instance)

            # Step 4: Map AI reasoning to output structure
            output_data = {
                "suggestion": ai_result.get("recommended_place_id") or ai_result.get("recommended_cuisine"),
                "justification": ai_result.get("reasoning"),
                "price_range": ai_result.get("budget", "") 
            }

            # Step 5: Update Firestore with the final decision
            doc_ref.update({
                "status": "completed",
                "output": output_data
            })

            # Step 6: Clear Realtime Database lobby (Cleanup)
            try:
                # rtdb is imported from firebase_admin.db
                rtdb.reference(f"participants/{room_id}").delete()
            except Exception as e:
                print(f"Warning: Failed to clean RTDB: {e}")

            return https_fn.Response(
                json.dumps({"message": "Success", "data": output_data}), 
                mimetype="application/json"
            )

        # =====================================================================
        # DEFAULT ROUTE: Health Check
        # =====================================================================
        return https_fn.Response("What2Eat API Online", status=200)

    except Exception as e:
        print(f"🔥 Critical Backend Error: {e}")
        return https_fn.Response(
            json.dumps({"error": str(e), "status": "error"}), 
            status=500, 
            mimetype="application/json"
        )
    
# ==================================================================================
# CLOUD FUNCTION 2: CLEANUP SERVICE
# ==================================================================================
# [NEW] This function is dedicated to running your background cleanup tasks.
# It uses the synchronous logic from 'cleanup_services.py'.
@https_fn.on_request(
    region="asia-southeast1",
    cors=options.CorsOptions(
        cors_origins="*", 
        cors_methods=["get", "post"]
    )
)
def cleanup_tasks(req: https_fn.Request) -> https_fn.Response:
    """
    Trigger endpoint for background cleanup.
    Can be called manually or by Cloud Scheduler.
    """
    try:
        print("🧹 Starting Scheduled Cleanup Tasks...")
        
        # 1. Clean Expired Rooms
        cleanup_expired_rooms()
        
        # 2. Clean Offline Participants
        cleanup_offline_participants()
        
        print("✅ Cleanup Finished Successfully")
        return https_fn.Response("Cleanup OK", status=200)
        
    except Exception as e:
        print(f"🔥 Cleanup Failed: {e}")
        return https_fn.Response(f"Error: {e}", status=500)