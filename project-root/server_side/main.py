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
    """
    yield

app = FastAPI(title="Group Dining AI Server", lifespan=lifespan)

# ---------------------------
# CORS Middleware
# ---------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------
# AI ROUTES
# ---------------------------
@app.post("/ai/participants")
async def ai_recommendation(request: Request):
    """
    Client sends participant data as JSON.
    Server calls AI (Gemini) to generate recommendation.
    """
    try:
        room_data = await request.json()
        result = our_model(room_data, maps_service_instance)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ===========================
# MAPS ROUTES (SERVER-SIDE)
# ===========================

@app.post("/maps/search")
async def search_places(request: Request):
    """
    Server-side Google Maps search.
    Used by client for restaurant search.
    """
    try:
        payload = await request.json()
        query = payload.get("query")

        if not query:
            raise HTTPException(status_code=400, detail="Query is required")

        results = maps_service_instance.search_places(query)

        # Normalize keys for client (camelCase)
        return [
            {
                "name": r.get("name"),
                "placeId": r.get("place_id"),
                "lat": r.get("lat"),
                "lng": r.get("lng"),
            }
            for r in results
        ]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/maps/place/{place_id}")
async def get_place_details(place_id: str):
    """
    Fetch place details for AI recommendation marker.
    """
    try:
        details = maps_service_instance.get_place_details(place_id)

        if not details:
            raise HTTPException(status_code=404, detail="Place not found")

        return {
            "placeId": details.get("place_id"),
            "name": details.get("name"),
            "lat": details.get("lat"),
            "lng": details.get("lng"),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
