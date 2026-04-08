INSERT INTO Users (identity_provider_id, email)
VALUES ('google-oauth2|123456789', 'traveler.demo@example.com')
ON CONFLICT (identity_provider_id) DO NOTHING;

-- 2. Insert Travelers (Profiles) and a Trip
-- We use a DO block to handle variable assignment for the foreign keys
DO $$
DECLARE
    v_user_id UUID;
    v_traveler_id_self UUID;
    v_traveler_id_spouse UUID;
    v_trip_id UUID;
    v_leg_id UUID;
BEGIN
    -- Get the ID of the user we just created (or that already existed)
    SELECT user_id INTO v_user_id FROM Users WHERE email = 'traveler.demo@example.com';

    -- Insert Primary Traveler (Self)
    INSERT INTO Travelers (user_id, full_name, relationship, date_of_birth, gender, nationality_code, medical_details, food_preferences)
    VALUES (v_user_id, 'Alex Smith', 'Self', '1990-05-15', 'MALE', 'US', 'None', 'Peanut Allergy')
    RETURNING traveler_id INTO v_traveler_id_self;

    -- Insert Companion (Spouse)
    INSERT INTO Travelers (user_id, full_name, relationship, date_of_birth, gender, nationality_code, medical_details, food_preferences)
    VALUES (v_user_id, 'Jordan Smith', 'Spouse', '1992-08-20', 'FEMALE', 'US', 'Asthma', 'Gluten Free')
    RETURNING traveler_id INTO v_traveler_id_spouse;

    -- 3. Create a Trip Container
    INSERT INTO Trips (user_id, trip_name, status)
    VALUES (v_user_id, 'Summer Europe Tour 2024', 'DRAFT')
    RETURNING trip_id INTO v_trip_id;

    -- 4. Insert Leg 1: London to Paris (Flight)
    INSERT INTO Trip_Legs (trip_id, sequence_number, sequence_order, start_country, start_city, start_coords, end_country, end_city, end_coords)
    VALUES (
        v_trip_id, 1, 1, 
        'United Kingdom', 'London', 'SRID=4326;POINT(-0.1278 51.5074)', 
        'France', 'Paris', 'SRID=4326;POINT(2.3522 48.8566)'
    )
    RETURNING leg_id INTO v_leg_id;

    -- Add Details for v_traveler_id_self on this leg
    INSERT INTO Traveler_Leg_Details (leg_id, traveler_id, travel_mode, departure_time, arrival_time, departure_timezone, arrival_timezone, transport_details)
    VALUES (
        v_leg_id, v_traveler_id_self, 'FLIGHT', 
        '2024-07-01 10:00:00+00', '2024-07-01 12:15:00+00', 
        'Europe/London', 'Europe/Paris', 
        '{"flight_number": "BA306", "seat": "14A", "gate": "A12"}'
    );

    -- Add Details for v_traveler_id_spouse on this leg
    INSERT INTO Traveler_Leg_Details (leg_id, traveler_id, travel_mode, departure_time, arrival_time, departure_timezone, arrival_timezone, transport_details)
    VALUES (
        v_leg_id, v_traveler_id_spouse, 'FLIGHT', 
        '2024-07-01 10:00:00+00', '2024-07-01 12:15:00+00', 
        'Europe/London', 'Europe/Paris', 
        '{"flight_number": "BA306", "seat": "14B", "gate": "A12"}'
    );

    -- 5. Insert Leg 2: Paris to Amsterdam (Train)
    INSERT INTO Trip_Legs (trip_id, sequence_number, sequence_order, start_country, start_city, start_coords, end_country, end_city, end_coords)
    VALUES (
        v_trip_id, 2, 2, 
        'France', 'Paris', 'SRID=4326;POINT(2.3522 48.8566)', 
        'Netherlands', 'Amsterdam', 'SRID=4326;POINT(4.9041 52.3676)'
    )
    RETURNING leg_id INTO v_leg_id;

    -- Add Details for v_traveler_id_spouse on this leg
    INSERT INTO Traveler_Leg_Details (leg_id, traveler_id, travel_mode, departure_time, arrival_time, departure_timezone, arrival_timezone, transport_details)
    VALUES (
        v_leg_id, v_traveler_id_self, 'TRAIN', 
        '2024-07-05 09:00:00+00', '2024-07-05 12:30:00+00', 
        'Europe/Paris', 'Europe/Amsterdam', 
        '{"train_number": "Eurostar 9321", "coach": "7", "seat": "42"}'
    );
END;
$$;