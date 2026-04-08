from google import genai
from apps.backend.config import GCP_PROJECT_ID, REGION, GEMINI_MODEL
import json
import asyncio

class AIService:
    def __init__(self):
        self.client = genai.Client(
            vertexai=True, 
            project=GCP_PROJECT_ID, 
            location=REGION
        )

    def generate_summary(self, full_prompt: str) -> str:
        """General function for any summary based on the passed prompt."""
        response = self.client.models.generate_content(
            model=GEMINI_MODEL,
            contents=full_prompt
        )
        return response.text.strip()

    async def generate_summary_async(self, prompt: str) -> str:
            """Asynchronous wrapper to allow parallel agent execution."""
            loop = asyncio.get_event_loop()
            # We run the blocking SDK call in a separate thread
            response = await loop.run_in_executor(
                None, 
                lambda: self.client.models.generate_content(
                    model=GEMINI_MODEL,
                    contents=prompt
                )
            )
            return response.text

