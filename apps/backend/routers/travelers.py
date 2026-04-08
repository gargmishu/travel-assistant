from fastapi import APIRouter, HTTPException, Depends
from apps.backend.services.db_service import fetch_traveler

router = APIRouter()

@router.get("/{user_id}/fetch/{traveler_id}")
async def get_traveler_info(user_id: str, traveler_id: str):
    """Simple check for a specific user's existence."""
    traveler = fetch_traveler(user_id, traveler_id)
    if not traveler:
        raise HTTPException(status_code=404, detail=f"Traveler {traveler_id} not found")
    return {"traveler": traveler}