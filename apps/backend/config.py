import os
from pathlib import Path
from dotenv import load_dotenv

# Path to travel-assistant/.env
# env_path = Path(__file__).resolve().parent.parent.parent / ".env"
# load_dotenv(dotenv_path=env_path)
load_dotenv()

GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
REGION = os.getenv("REGION")
CLUSTER_ID = os.getenv("CLUSTER_ID")
INSTANCE_ID = os.getenv("INSTANCE_ID")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
GEMINI_MODEL = os.getenv("GEMINI_MODEL")