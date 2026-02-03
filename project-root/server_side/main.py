from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# Server-side logic
from server_side.src.logic.process_actions import our_model, maps_service_instance

app = FastAPI(title="Group Dining AI Server")

# Allow client-side web app to call API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change to your client domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------
# ROUTES
# ---------------------------

@app.post("/ai/participants")
async def ai_recommendation(request: Request):
    """
    Client sends participant data as JSON.
    Server converts it and calls AI (Gemini) to generate recommendation.
    Returns: {"status", "recommended_place_id", "recommended_cuisine", "justification"}
    """
    try:
        room_data = await request.json()
        result = our_model(room_data, maps_service_instance)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
