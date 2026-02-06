from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Server-side logic
from server_side.src.logic.process_actions import our_model, maps_service_instance

# ---------------------------
# Lifespan / Startup Setup
# ---------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context for startup/shutdown tasks.
    Currently no background tasks are run here, because cleanup is handled
    by Cloud Scheduler + Cloud Functions.
    """
    # Startup code (e.g., initialize services) could go here
    yield
    # Shutdown code (if needed) could go here

app = FastAPI(title="Group Dining AI Server", lifespan=lifespan)

# ---------------------------
# CORS Middleware
# ---------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change to your client domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------
# API ROUTES
# ---------------------------
@app.post("/ai/participants")
async def ai_recommendation(request: Request):
    """
    Client sends participant data as JSON.
    Server converts it and calls AI (Gemini) to generate recommendation.

    Returns a dictionary:
    {
        "status": str,
        "recommended_place_id": str,
        "recommended_cuisine": str,
        "justification": str
    }
    """
    try:
        room_data = await request.json()
        result = our_model(room_data, maps_service_instance)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
