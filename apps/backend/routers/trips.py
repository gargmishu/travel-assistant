import asyncio
import json
from fastapi import APIRouter, HTTPException, Depends, Query
from apps.backend.services.db_service import (
    fetch_trip_details, 
    fetch_travelers_for_trip, 
    fetch_traveler_profiles
)
from apps.backend.services.ai_service import AIService

router = APIRouter()


@router.get("/{user_id}/smart-tips/{trip_id}")
async def smart_travel_tips(
    trip_id: str, 
    user_id: str, # = Query(..., description="Mandatory User ID for authorization"),
    ai_service: AIService = Depends()
):
    """
    Multi-Agent Architecture using Tool-Calling (MCP Pattern):
    - DB Agents: Fetch Ground Truth (Trip, Manifest, Profiles).
    - AI Orchestrator: Calls Weather & Places tools.
    - Synthesis: Returns structured JSON.
    """
    # 1. Fetch Core Data (Ground Truth)
    trip = fetch_trip_details(trip_id, user_id)
    if not trip:
        raise HTTPException(status_code=404, detail=f"Trip id {trip_id} not found.")

    # 2. Fetch Traveler details
    traveler_ids = fetch_travelers_for_trip(trip_id)
    if not traveler_ids:
        raise HTTPException(status_code=404, detail=f"Traveler ids for trip id {trip_id} not found.")

    traveler_profiles = fetch_traveler_profiles(traveler_ids)
    if not traveler_profiles:
        raise HTTPException(status_code=404, detail=f"Traveler details for traveler ids {traveler_ids} not found.")

    # return {"travelers_profiles": profiles}
    
    # 3. Trigger the Multi-Agent Workflow
    # The AIService now handles Parallel research (Weather/Places/Rules) 
    # and Sequential synthesis into JSON.
    try:
        # Note: we use the new method name we defined in ai_service.py
        result_json = await ai_service.generate_smart_tips(
            trip_data=trip, 
            traveler_profiles=traveler_profiles
        )
        return result_json
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="AI returned invalid JSON format.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"hello Agentic Workflow failed again3: {str(e)}")