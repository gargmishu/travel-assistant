from google import genai
from google.adk import Agent
from google.adk.tools import McpToolset
from google.genai import types
from apps.backend.config import GCP_PROJECT_ID, REGION, GEMINI_MODEL
import json
import asyncio
from google.adk import Agent
from google.adk.models.google_llm import Gemini
from google.adk.tools.mcp_tool import McpToolset, StdioConnectionParams
from mcp import StdioServerParameters
from google.adk.agents import ParallelAgent, SequentialAgent
from google.adk.tools.tool_context import ToolContext
import logging
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from typing import List, Dict, Any

# Configure the logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

retry_config = types.HttpRetryOptions(
    attempts=5,          # Maximum retry attempts
    exp_base=7.0,        # Delay multiplier
    initial_delay=1.0,   # Initial delay in seconds
    http_status_codes=[429, 500, 503, 504]
)

generate_content_config = types.GenerateContentConfig(
    temperature=0.7,
    response_mime_type="application/json"
)

# Initialize the Open-Meteo MCP (No Key Required)
weather_mcp = McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command="npx",
            args=["-y", "@smithery/mcp-weatherserver"],
        )
    )
)

# Initialize the Google Maps MCP
maps_mcp = McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command="npx",
            args=["-y", "@google/mcp-server-google-maps"],
            env={"GOOGLE_MAPS_API_KEY": "YOUR_API_KEY"}
        )
    )
)

# OpenStreetMap Toolset (for terrain/hiking/paths)
open_street_map_mcp = McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command="npx",
            args=["-y", "@smithery/mcp-osm-server"]
        )
    )
)

def get_workflow_output(response):
    # The last element in the list is the completion of the SequentialAgent
    last_event = response[-1]
    
    actions = last_event.get("actions", {})

    # Check both naming conventions just in case
    state_delta = actions.get("stateDelta") or actions.get("state_delta") or {}

    final_json_str = state_delta.get("final_json")

    if final_json_str:
        try:
            return json.loads(final_json_str)
        except (json.JSONDecodeError, TypeError):
            return {"raw_output": final_json_str}

    return {"error": "final_json not found in state", "debug": state_delta}


class AIService:
    def __init__(self):
        self.client = genai.Client(
            vertexai=True, 
            project=GCP_PROJECT_ID, 
            location=REGION
        )
        self.model = Gemini(model=GEMINI_MODEL, retry_options=retry_config)

        # 1. Weather Specialist
        self.weather_agent = Agent(
            name="WeatherSpecialist",
            model=self.model,
            tools=[weather_mcp],
            generate_content_config=generate_content_config,
            instruction="""
            You're a long-range weather specialist.
            Extract 'trip_data' and 'traveler_profiles' from the user's message & analyze it.
    
            1. Extract 'trip_data' and locations.
            2. For trip dates within 16 days, use the standard forecast tool.
            3. For dates between 16 and 90 days, use the 'seasonal_forecast' or 'climate' 
                capabilities of the Open-Meteo tool to provide estimated conditions.
    
            Analyze temperature trends and precipitation likelihood. Even for long-range 
            dates (up to 90 days), provide a report based on historical climate models.

            Output your findings as a concise report for the next agent.
            """,
            output_key="weather_report"
        )

        # 2. Destination & Activities Specialist
        self.places_agent = Agent(
            name="DestinationSpecialist",
            model=self.model,
            tools=[maps_mcp, open_street_map_mcp],
            generate_content_config=generate_content_config,
            instruction="""
            You're a travel agent & local specialist.
            Extract 'trip_data' and 'traveler_profiles' from the user's message & analyze it.

            Focus on geography and activities.
            1. Use Google Maps to find 3 must-do activities and identify formal/urban settings.
            2. Use OpenStreetMap to verify terrain steepness and path surface types.
            3. Predict walking intensity based on elevation gain and ground surface.
            4. Suggest 3 must-do activities.

            Output your findings as a concise report for the next agent.
            """,
            output_key="places_report"
        )

        # 3. Logistics & Rules Specialist
        self.logistics_agent = Agent(
            name="LogisticsSpecialist",
            model=self.model,
            instruction="""
            You're a Logistics expert
            Extract 'trip_data' and 'traveler_profiles' from the user's message & analyze it.

            Focus on travel rules & restrictions.
            Research typical baggage limits for the mode of transport and common customs 
            or travel restrictions for the destination (e.g., medication restrictions, 
            power outlet types, or visa-specific gear).

            Output your findings as a concise report for the next agent.
            """,
            output_key="logistics_report"
        )

        # 4. The Master Synthesizer (The Editor)
        self.synthesizer_agent = Agent(
            name="master_synthesizer",
            model=self.model,
            generate_content_config=generate_content_config,
            instruction="""
            Extract 'trip_data' and 'traveler_profiles' from the user's message & analyze it.

            You will also receive

            **Weather information:**
            {weather_report}

            **Destination information:**
            {places_report}

            **Logistic information:**
            {logistics_report}
            
            Create a comprehensive packing list in STRICT JSON format.
            Include the number of items wherever possible; ex: 5 T-shirt, 3 pants
            Be as specific as possible.

             STRICT OUTPUT RULES:
            - Return ONLY valid JSON.
            - No markdown formatting (no ```json).
            - Ensure 'medical' notes address specific traveler needs found in traveler_profiles.
            
            JSON Structure:
            {
              "clothing": { "logic": "explanation", "items": [] },
              "undergarments": { "logic": "explanation", "items": [] },
              "accessories": { "logic": "explanation", "items": [] },
              "toilteries": { "logic": "explanation", "items": [] },
              "traveler_medical_needs": [ "<traveler_id>": { "logic": "explanation", "items[]}],
              "first_aid_items": { "logic": "explanation", "items": [] },
              "gear": { "logic": "explanation", "items": [] },
              "places_to_visit: { "logic": "explanation", "items": [] }
              "activities_to_do": { "logic": "explanation", "items": [] }
            }
            """,
            output_key="final_json"
        )

        # 5. Defining the Agentic Workflow
        # Parallel phase: Researching happens at the same time
        self.research_phase = ParallelAgent(
            name="TravelResearchPhase",
            sub_agents=[self.weather_agent, self.places_agent, self.logistics_agent]
        )

        self.travel_workflow = SequentialAgent(
            name="SmartTravelWorkflow",
            sub_agents=[self.research_phase, self.synthesizer_agent]
        )


    async def generate_smart_tips(self, trip_data: dict, traveler_profiles: list) -> dict:
        """
        Executes the logic-only agentic workflow.
        """

        # Get app name from the Runner
        app_name = "TravelAssistant"
        USER_ID = "default_user"
        session_id = "current_trip_session"

        try:
            # 1. Setup a session service (to remember context)
            session_service = InMemorySessionService()

            # 2. Attempt to create a new session or retrieve an existing one
            try:
                session = await session_service.create_session(
                    app_name=app_name, user_id=USER_ID, session_id=session_id
                )
            except:
                session = await session_service.get_session(session_id)
            
            # 3. Initialize the Runner
            runner = Runner(
                agent=self.travel_workflow, 
                app_name=app_name,
                session_service=session_service
            )   

            # 4. Run the workflow
            serializable_state = json.loads(json.dumps({
                "trip_data": trip_data,
                "traveler_profiles": traveler_profiles
            }, default=str))
            prompt_text = f"""
                Initialize the system with the following data:
                Trip Data: {serializable_state["trip_data"]},
                Traveler Profiles: {serializable_state["traveler_profiles"]}
                After initializing, generate my packing list.
                """
            query = types.Content(role="user", parts=[types.Part(text=prompt_text)])
            response_generator = runner.run(
                user_id=USER_ID,
                session_id=session.id,
                new_message=query,
            )

            # 5. Process the response
            # Use a list comprehension to convert all Event objects to dictionaries
            # This handles the 'not subscriptable' error for the whole response
            response = [
                step.model_dump() if hasattr(step, "model_dump") else vars(step) 
                for step in response_generator
            ]

            if response is None:
                logger.error("Runner returned None. Check agent logs for model invocation errors.")
                return {"error": "Workflow failed to generate a response"}
            
            return get_workflow_output(response)
            
        except Exception as e:
            logger.error(f"hello, hello... Agentic Workflow failed again: {e}")
            raise e