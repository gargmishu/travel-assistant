from fastapi import APIRouter, Depends
from apps.backend.services.ai_service import AIService
from apps.backend.services.db_service import get_db_timestamp

router = APIRouter()

@router.get("/tip")
async def get_tip(prompt: str = "Give me a quick travel tip", ai_service: AIService = Depends()):
    try:
        return {"tip": ai_service.generate_summary(prompt)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/db-check")
async def db_check():
    try:
        timestamp = get_db_timestamp()
        return {"database_time": timestamp}
    except Exception as e:
        return {"error": f"Database connection failed: {str(e)}"}