from fastapi import APIRouter, HTTPException, Depends
from apps.backend.services.db_service import fetch_all_user_ids, fetch_user, fetch_user_trips, fetch_all_travelers, fetch_family_data_from_db
from apps.backend.services.ai_service import AIService

router = APIRouter()

@router.get("/list")
async def list_users():
    """Returns all registered user IDs."""
    try:
        users = fetch_all_user_ids()
        return {"users": users}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")

@router.get("/{user_id}")
async def get_user_status(user_id: str):
    """Simple check for a specific user's existence."""
    # In a real app, you'd fetch a full profile here
    user = fetch_user(user_id)
    if not user:
        raise HTTPException(status_code=404, detail=f"User {user_id} not found")
    return {"user": user}

@router.get("/{user_id}/list-travelers")
async def list_travelers(user_id: str):
    """Returns all travelers for a user id."""
    try:
        travelers = fetch_all_travelers(user_id)
        return {"travelers": travelers}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")

@router.get("/{user_id}/list-trips")
async def list_user_trips(user_id: str):
    """Returns all trips (draft, active, completed) for a user id."""
    try:
        trips = fetch_user_trips(user_id)
        if not trips:
            # We return an empty list rather than 404 if the user exists but has no trips
            return {"user_id": user_id, "trips": []}
        return {"user_id": user_id, "trips": trips}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")

@router.get("/{user_id}/family-health-info")
async def get_family_health_info(user_id: str):
    result = fetch_family_data_from_db(user_id)
    if not result:
        raise HTTPException(status_code=404, detail=f"No travelers found for {user_id}.")
    return {"travelers": result}

@router.get("/{user_id}/family-health-summary")
async def get_travel_summary(user_id: str, ai_service: AIService = Depends()):
    rows = fetch_family_data_from_db(user_id)
    if not rows:
        raise HTTPException(status_code=404, detail=f"No travelers found for {user_id}.")
    
    raw_data_string = "\n".join([
        f"- {p['full_name']} ({p['relationship']}): Food: {p['food_preferences']}, Medical: {p['medical_details']}"
        for p in rows
    ])

    prompt = f"""
    You are a professional travel assistant. Provide a concise summary (2-3 sentences) 
    of these requirements for a flight manifest. Focus on critical allergies.
    
    Traveler Data:
    {raw_data_string}
    """
    
    summary = ai_service.generate_summary(prompt)
    return {
        "user_id": user_id,
        "family_size": len(rows),
        "ai_summary": summary
    }