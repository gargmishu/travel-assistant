from google.cloud.alloydb.connector import Connector
from sqlalchemy import create_engine
from apps.backend.config import GCP_PROJECT_ID, REGION, CLUSTER_ID, INSTANCE_ID, DB_USER, DB_PASSWORD, DB_NAME

connector = Connector()

def get_conn():
    return connector.connect(
        f"projects/{GCP_PROJECT_ID}/locations/{REGION}/clusters/{CLUSTER_ID}/instances/{INSTANCE_ID}",
        "pg8000",
        user=DB_USER,
        password=DB_PASSWORD,
        db=DB_NAME,
        ip_type="public"
    )

engine = create_engine(
    "postgresql+pg8000://",
    creator=get_conn,
    pool_pre_ping=True
)