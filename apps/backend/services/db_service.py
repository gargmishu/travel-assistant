from sqlalchemy import text
from apps.backend.database import engine

def get_db_timestamp():
    query = text("SELECT NOW()")
    with engine.connect() as conn:
        result = conn.execute(query).fetchone()
        return str(result[0])

def fetch_all_user_ids():
    query = text("SELECT user_id FROM Users")
    with engine.connect() as conn:
        result = conn.execute(query).fetchall()
        return [row[0] for row in result]

def fetch_user(user_id: str):
    """Fetches basic details for a specific User ID."""
    query = text("SELECT user_id, email, created_at FROM Users WHERE user_id = :user_id")
    with engine.connect() as conn:
        return conn.execute(query, {"user_id": user_id}).mappings().all()

def fetch_all_travelers(user_id: str):
    """Fetches all travelers linked to a user."""
    query = text("SELECT * FROM Travelers WHERE user_id = :user_id")
    with engine.connect() as conn:
        return conn.execute(query, {"user_id": user_id}).mappings().all()

def fetch_user_trips(user_id: str):
    """Fetches all trips created by a specific user."""
    query = text("""
        SELECT trip_id, trip_name, status, created_at 
        FROM Trips 
        WHERE user_id = :user_id 
        ORDER BY created_at DESC
    """)
    with engine.connect() as conn:
        return conn.execute(query, {"user_id": user_id}).mappings().all()

def fetch_family_data_from_db(user_id: str):
    query = text("""
        SELECT full_name, relationship, food_preferences, medical_details
        FROM Travelers
        WHERE user_id = :user_id
        ORDER BY CASE WHEN relationship = 'Self' THEN 0 ELSE 1 END;
    """)
    with engine.connect() as conn:
        return conn.execute(query, {"user_id": user_id}).mappings().all()

def fetch_traveler(user_id: str, traveler_id: str):
    """Fetches a single traveler record verified by user ownership."""
    query = text("""
        SELECT * FROM Travelers 
        WHERE traveler_id = :t_id AND user_id = :u_id
    """)
    with engine.connect() as conn:
        # .mappings().first() returns a dictionary-like object or None
        return conn.execute(query, {"t_id": traveler_id, "u_id": user_id}).mappings().all()

def fetch_trip_details(trip_id: str, user_id: str):
    """
    Fetches the destination and date range for a specific trip.
    Since your schema uses Trip_Legs, we find the first and last leg.
    """
    query = text("""
        SELECT 
            t.trip_id, 
            t.trip_name,
            STRING_AGG(DISTINCT tl.start_city, ', ' ORDER BY tl.start_city) as all_start_cities,
            STRING_AGG(DISTINCT tl.end_city, ', ' ORDER BY tl.end_city) as all_destinations,
            MIN(tld.departure_time) as start_date,
            MAX(tld.arrival_time) as end_date
        FROM Trips t
        JOIN Trip_Legs tl ON t.trip_id = tl.trip_id
        JOIN Traveler_Leg_Details tld ON tl.leg_id = tld.leg_id
        WHERE t.trip_id = :trip_id AND t.user_id = :user_id
        GROUP BY t.trip_id;
    """)
    with engine.connect() as conn:
        # .first() ensures we get one dictionary-like object back
        return conn.execute(query, {"trip_id": trip_id, "user_id": user_id}).mappings().first()

def fetch_travelers_for_trip(trip_id: str):
    """
    Gets the list of unique traveler IDs associated with all legs of a trip.
    """
    query = text("""
        SELECT DISTINCT traveler_id 
        FROM Traveler_Leg_Details tld
        JOIN Trip_Legs tl ON tld.leg_id = tl.leg_id
        WHERE tl.trip_id = :trip_id;
    """)
    with engine.connect() as conn:
        result = conn.execute(query, {"trip_id": trip_id}).fetchall()
        return [row[0] for row in result]

def fetch_traveler_profiles(traveler_ids: list):
    """
    Fetches the health, gender, and preference data for specific travelers.
    """
    if not traveler_ids:
        return []
    
    query = text("""
        SELECT full_name, relationship, gender, medical_details, food_preferences, date_of_birth
        FROM Travelers
        WHERE traveler_id = ANY(CAST(:ids AS UUID[]))
    """)
    with engine.connect() as conn:
        return conn.execute(query, {"ids": traveler_ids}).mappings().all()
