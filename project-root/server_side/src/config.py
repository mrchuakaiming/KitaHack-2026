# server_side/config.py

import os
from dotenv import load_dotenv

# Load environment variables from a .env file at project root
load_dotenv()

# ==========================
# Gemini API
# ==========================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY not set in environment variables")

# ==========================
# Google Maps API
# ==========================
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
if not GOOGLE_MAPS_API_KEY:
    raise ValueError("GOOGLE_MAPS_API_KEY not set in environment variables")

# ==========================
# Firebase Admin SDK
# ==========================
# Path to the Firebase Admin SDK JSON file
FIREBASE_ADMIN_KEY_PATH = os.getenv("FIREBASE_ADMIN_KEY_PATH") #path to firebase.json
if not FIREBASE_ADMIN_KEY_PATH or not os.path.exists(FIREBASE_ADMIN_KEY_PATH):
    raise ValueError("FIREBASE_ADMIN_KEY_PATH not set or file does not exist")
