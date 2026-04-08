from fastapi import FastAPI
from contextlib import asynccontextmanager
from apps.backend.database import engine, connector
from apps.backend.routers import travelers, trips, users, common

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handles startup and shutdown of global resources."""
    print("--- Starting up Travel Assistant API ---")
    yield
    print("--- Shutting down ---")
    engine.dispose()
    connector.close()

app = FastAPI(
    title="Travel Assistant API", 
    lifespan=lifespan
)

# 1. Home / Health Check Endpoint
@app.get("/")
async def home():
    """
    Root endpoint to verify the API is online.
    Provides links to documentation and basic status.
    """
    return {
        "status": "online",
        "message": "Welcome to the Travel Assistant API",
        "database_connected": engine is not None
    }

# 2. Include the Modular Routers

# Giving them prefixes makes the API intuitive
app.include_router(users.router, prefix="/users", tags=["Users"])
app.include_router(travelers.router, prefix="/travelers", tags=["Travelers"])
app.include_router(trips.router, prefix="/trips", tags=["Trips & AI"])
app.include_router(common.router, tags=["General"]) # No prefix for general/root