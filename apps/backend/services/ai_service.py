from google import genai
from google.genai import types
from apps.backend.config import GCP_PROJECT_ID, REGION, GEMINI_MODEL
import json
import asyncio
from google.adk import Agent
from google.adk.agents import ParallelAgent, SequentialAgent
from google.adk.tools.tool_context import ToolContext
# from google.adk.tools.invocation_context import InvocationContext
import logging
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from typing import List, Dict, Any

# Configure the logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def load_trip_context(
    tool_context: ToolContext,
    trip_data: Dict[str, Any],
    traveler_profiles: List[Dict[str, Any]]
) -> dict[str, str]:
    """Saves the trip details & traveler profiles to the state.""" 

    tool_context.state["trip_data"] = trip_data
    tool_context.state["traveler_profiles"] = traveler_profiles

    return {"status": "success"}


class AIService:
    def __init__(self):
        self.client = genai.Client(
            vertexai=True, 
            project=GCP_PROJECT_ID, 
            location=REGION
        )
        self.model_name = GEMINI_MODEL

        # 0. Data loader agent
        self.loader_agent = Agent(
            name="LoaderAgent",
            model=self.model_name,
            tools=[load_trip_context],
            instruction="""
            You are the Data Entry Specialist. 
            1. Extract 'trip_data' and 'traveler_profiles' from the user's message.
            2. Call 'load_trip_context' with these exact objects.
            3. Once successful, confirm that the context is set.
            DO NOT perform any travel analysis; simply load the data.
            """,
            output_key="load_status"
        )

        # 1. Weather Specialist
        self.weather_agent = Agent(
            name="WeatherSpecialist",
            model=self.model_name   ,
            instruction="""
            You will receive 'trip_data' and 'traveler_profiles in the state. 


            # Analyze {trip_data}. Focus ONLY on meteorology.
            Predict temperature swings, precipitation chances, and humidity.
            
            Output your findings as a concise report for the next agent.
            """,
            output_key="weather_report"
        )

        # 2. Destination & Activities Specialist
        self.places_agent = Agent(
            name="DestinationSpecialist",
            model=self.model_name,
            instruction="""
            You will receive 'trip_data' and 'traveler_profiles in the state. 

            Focus on geography and activities.
            Identify if the trip involves steep terrain, water activities, or formal urban settings.
            Suggest if walking intensity will be high. 
            Identify the terrain and suggest 3 must-do activities.

            Output your findings as a concise report for the next agent.
            """,
            output_key="places_report"
        )

        # 3. Logistics & Rules Specialist
        self.logistics_agent = Agent(
            name="LogisticsSpecialist",
            model=self.model_name,
            instruction="""
            You will receive 'trip_data' and 'traveler_profiles in the state. 

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
            model=self.model_name,
            instruction="""
            You will receive 'trip_data' and 'traveler_profiles in the state. 

            You will also receive

            **Weather information:**
            {weather_report}

            **Destination information:**
            {places_report}

            **Logistic information:**
            {logistics_report}
            
            Create a comprehensive packing list in STRICT JSON format.
            Ensure the 'gear' section accounts for both the terrain and the travel rules.

             STRICT OUTPUT RULES:
            - Return ONLY valid JSON.
            - No markdown formatting (no ```json).
            - Ensure 'medical' notes address specific traveler needs found in traveler_profiles.
            
            JSON Structure:
            {
              "clothing": { "logic": "explanation", "items": [] },
              "accessories": [],
              "medical": { "traveler_specific_notes": [], "kit_additions": [] },
              "gear": []
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

    async def generate_smart_tips(self, trip_data: dict, traveler_profiles: list) -> dict:
        """
        Executes the logic-only agentic workflow.
        """
        
        travel_workflow = SequentialAgent(
            name="SmartTravelWorkflow",
            # tools=[add_trip_details_to_state],
            sub_agents=[self.loader_agent, self.research_phase, self.synthesizer_agent]
        )

        # Get app name from the Runner
        app_name = "TravelAssistant"
        USER_ID = "default_user"
        session_name = "current_trip_session"

        try:
            # 1. Setup a session service (to remember context)
            session_service = InMemorySessionService()

            # 2. Attempt to create a new session or retrieve an existing one
            try:
                session = await session_service.create_session(
                    app_name=app_name, user_id=USER_ID, session_id=session_name
                )
            except:
                session = await session_service.get_session(
                    app_name=app_name, user_id=USER_ID, session_id=session_name
                )
            

            # 3. Inject your data into the session state
            # logger.info(f"Blank Session State: {session.state}")
            # serializable_state = json.loads(json.dumps({
            #     "trip_data": trip_data,
            #     "traveler_profiles": traveler_profiles
            # }, default=str))
            # session.state.update(serializable_state)
            
            # session.state["trip_data"] = serializable_state["trip_data"]
            # session.state["traveler_profiles"] = serializable_state["traveler_profiles"]
            # # Check if your service needs an explicit save
            # if hasattr(session_service, 'update_session'):
            #     await session_service.update_session(session)
            # logger.info(f"Verified Session Keys: {session.state.keys()}")
            # logger.info(f"Updated Session State: {session.state}")
            
            # 4. Initialize the Runner
            runner = Runner(
                agent=travel_workflow, 
                app_name=app_name,
                session_service=session_service
            )   

            # 5. Run the workflow
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
            response = runner.run(
                user_id=USER_ID,
                session_id=session.id,
                new_message=query,
            )

            if response is None:
                logger.error("Runner returned None. Check agent logs for model invocation errors.")
                return {"error": "Workflow failed to generate a response"}
            
            # final_output = response.text
            return response
            # logger.info(f"response = {response}")
            # # 6. Extract the result from the response state
            # final_output = response.state.get("final_json")
            
            # # Fallback if final_json is missing from state but present in text
            # if not final_output:
            #     final_output = response.text
            
            # if isinstance(final_output, str):
            #     clean_json = final_output.strip().replace("```json", "").replace("```", "")
            #     return json.loads(clean_json)
            
            # return final_output
            # print(response.text)
            # # This triggers the sequential hand-off between agents
            # raw_output = await self.travel_workflow. (state=initial_data)
            
            # Basic cleaning in case the model ignores instructions and adds backticks
            # clean_json = raw_output.strip().replace("```json", "").replace("```", "")
            # return json.loads(clean_json)
            
        except Exception as e:
            logger.error(f"hello, hello... Agentic Workflow failed again: {e}")
            raise e