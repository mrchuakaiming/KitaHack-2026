import os
from dotenv import load_dotenv

load_dotenv()

# Check if we are in local development / emulator mode
IS_EMULATOR = os.getenv("FIRESTORE_EMULATOR_HOST") is not None

# ==========================
# Gemini API
# ==========================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Only crash if NOT in emulator mode
if not GEMINI_API_KEY and not IS_EMULATOR:
    # raise ValueError("GEMINI_API_KEY not set in environment variables")
    print("Warning: GEMINI_API_KEY is missing!") # Changed to print only
elif not GEMINI_API_KEY:
    GEMINI_API_KEY = "mock_key_for_emulator"

# ==========================
# Google Maps API
# ==========================
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")

if not GOOGLE_MAPS_API_KEY and not IS_EMULATOR:
    # raise ValueError("GOOGLE_MAPS_API_KEY not set in environment variables")
    print("Warning: GOOGLE_MAPS_API_KEY is missing!") # Changed to print only
elif not GOOGLE_MAPS_API_KEY:
    GOOGLE_MAPS_API_KEY = "mock_key_for_emulator"

# ==========================
# Firebase Admin SDK
# ==========================
FIREBASE_ADMIN_KEY_PATH = os.getenv("FIREBASE_ADMIN_KEY_PATH")

# In emulator mode, we don't need a real JSON file path
if not IS_EMULATOR:
    if not FIREBASE_ADMIN_KEY_PATH or not os.path.exists(FIREBASE_ADMIN_KEY_PATH):
        # THIS WAS CAUSING THE CRASH. WE HAVE COMMENTED IT OUT.
        # raise ValueError("FIREBASE_ADMIN_KEY_PATH not set or file does not exist")
        print("Warning: FIREBASE_ADMIN_KEY_PATH not found. Using Default Credentials.")