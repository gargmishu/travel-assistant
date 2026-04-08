-- Enable PostGIS for GEOGRAPHY type, uuid-ossp for UUID generation & vector for embeddings
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. Users (The Account/Identity Owner)
CREATE TABLE IF NOT EXISTS Users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    identity_provider_id TEXT UNIQUE NOT NULL, -- The 'sub' claim from Google Identity Platform
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Travelers (Profiles managed by a User)
DO $$ BEGIN
    CREATE TYPE gender_enum AS ENUM ('MALE', 'FEMALE', 'NON_BINARY', 'PREFER_NOT_SAY');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS Travelers (
    traveler_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    relationship VARCHAR(50), -- e.g., 'Self', 'Spouse', 'Child', 'Friend'
    date_of_birth DATE NOT NULL,
    gender gender_enum NOT NULL,
    nationality_code CHAR(2) NOT NULL, -- ISO 3166-1 alpha-2 (e.g., 'US', 'GB')
    medical_details TEXT,              -- Specific conditions for Medical Agent
    food_preferences TEXT,             -- Allergies for Root Agent warnings
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Trips (The Container for the Journey)
DO $$ BEGIN
    CREATE TYPE trip_status AS ENUM ('DRAFT', 'VERIFIED', 'ACTIVE', 'COMPLETED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS Trips (
    trip_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES Users(user_id),
    trip_name TEXT NOT NULL,
    status trip_status DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. Trip_Legs 
DO $$ BEGIN
    CREATE TYPE travel_mode_enum AS ENUM ('FLIGHT', 'TRAIN', 'BUS', 'ROAD_TRIP', 'FERRY');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS Trip_Legs (
    leg_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID NOT NULL REFERENCES Trips(trip_id) ON DELETE CASCADE,
    sequence_number INT NOT NULL,
    
    -- Location Data
    start_country VARCHAR(255) NOT NULL,
    start_city VARCHAR(255) NOT NULL,
    start_coords GEOGRAPHY(POINT, 4326),
    
    end_country VARCHAR(255) NOT NULL,
    end_city TEXT NOT NULL,
    end_coords GEOGRAPHY(POINT, 4326), 

    sequence_order INT NOT NULL, -- To keep legs in the right order
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. Traveler_Leg_Details Details
CREATE TABLE IF NOT EXISTS Traveler_Leg_Details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    leg_id UUID NOT NULL REFERENCES Trip_Legs(leg_id) ON DELETE CASCADE,
    traveler_id UUID NOT NULL REFERENCES Travelers(traveler_id) ON DELETE CASCADE,

    travel_mode travel_mode_enum NOT NULL,
    
    -- Travel time details
    departure_time TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_time TIMESTAMP WITH TIME ZONE NOT NULL,
    departure_timezone VARCHAR(50) NOT NULL,
    arrival_timezone VARCHAR(50) NOT NULL,
    
    -- Mode-Specific Metadata (Dynamic details like Flight # or Train Line)
    transport_details JSONB, 
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(leg_id, traveler_id)
);
