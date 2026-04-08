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

    profiles = fetch_traveler_profiles(traveler_ids)
    if not profiles:
        raise HTTPException(status_code=404, detail=f"Traveler details for traveler ids {traveler_ids} not found.")

    # return {"travelers_profiles": profiles}
    
    # Step 3: Parallel Research Agents (Fan-Out)
    # We trigger these simultaneously to save time
    weather_task = ai_service.generate_summary_async(
        f"Predict typical weather and rainfall for {trip['all_destinations']} starting {trip['start_date']}."
    )
    tourism_task = ai_service.generate_summary_async(
        f"List top activities in {trip['all_destinations']} starting {trip['start_date']}. Is it trekking, beach, or city tour?"
    )

    # Step 4: Orchestrator Agent (Synthesis)
    weather_info, destination_context = await asyncio.gather(weather_task, tourism_task)
    final_orchestration_prompt = f"""
    Act as a Master Travel Logistics Expert. 
    Using the context below, generate a STRICT JSON packing and prep guide.

    TRIP: {trip}
    TRAVELERS: {profiles}
    WEATHER: {weather_info}
    CONTEXT: {destination_context}

    JSON STRUCTURE:
    {{
      "clothing": {{ "logic": "Explain item counts based on days", "items": [] }},
      "accessories": ["Weather and activity specific"],
      "medical": {{ "traveler_specific_notes": [], "kit_additions": [] }},
      "toiletries": {{ "general": [], "gender_specific": [] }},
      "gear": ["Mode of transport specific gear"]
    }}
    """

    try:
        raw_ai_response = await ai_service.generate_summary_async(final_orchestration_prompt)
        # Clean up Markdown backticks if Gemini includes them
        clean_json = raw_ai_response.strip("`").replace("json", "").strip()
        return json.loads(clean_json)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Orchestration failed: {str(e)}")