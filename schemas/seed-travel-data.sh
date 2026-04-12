DO $$
DECLARE
    u_idx INT;
    t_idx INT;
    trip_idx INT;
    leg_idx INT;
    v_user_id UUID;
    v_trip_id UUID;
    v_leg_id UUID;
    
    -- Arrays for random data generation
    v_names TEXT[] := ARRAY['Alice', 'Bob', 'Charlie', 'Diana', 'Edward', 'Fiona', 'George', 'Hannah'];
    v_cities TEXT[] := ARRAY['New York', 'London', 'Tokyo', 'Berlin', 'Rome', 'Sydney'];
    v_countries TEXT[] := ARRAY['USA', 'UK', 'Japan', 'Germany', 'Italy', 'Australia'];
    
    v_traveler_count INT;
    v_trip_count INT;
    v_leg_count INT;
    v_travelers_in_trip INT;
    v_current_traveler_ids UUID[];
BEGIN
    -- 1. Create 5 Users
    FOR u_idx IN 1..5 LOOP
        INSERT INTO Users (identity_provider_id, email)
        VALUES ('auth0|' || gen_random_uuid(), 'user' || u_idx || '@example.com')
        RETURNING user_id INTO v_user_id;

        -- 2. Each user has 2-5 Travelers
        v_traveler_count := floor(random() * (5 - 2 + 1) + 2);
        v_current_traveler_ids := ARRAY[]::UUID[];
        
        FOR t_idx IN 1..v_traveler_count LOOP
            INSERT INTO Travelers (user_id, full_name, relationship, date_of_birth, gender, nationality_code)
            VALUES (
                v_user_id, 
                v_names[1 + mod(t_idx + u_idx, 8)] || ' Smith', 
                CASE WHEN t_idx = 1 THEN 'Self' ELSE 'Companion' END,
                '1990-01-01'::DATE + (random() * 10000)::INT,
                'PREFER_NOT_SAY',
                'US'
            ) RETURNING traveler_id INTO v_leg_id; -- Reusing variable for temp storage
            v_current_traveler_ids := array_append(v_current_traveler_ids, v_leg_id);
        END LOOP;

        -- 3. Each user has 0-3 Trips
        v_trip_count := floor(random() * 4); -- Generates 0, 1, 2, or 3
        
        FOR trip_idx IN 1..v_trip_count LOOP
            INSERT INTO Trips (user_id, trip_name, status)
            VALUES (v_user_id, 'Adventure ' || trip_idx, 'DRAFT')
            RETURNING trip_id INTO v_trip_id;

            -- 4. Each trip has 0-3 Legs
            v_leg_count := floor(random() * 4);
            FOR leg_idx IN 1..v_leg_count LOOP
                INSERT INTO Trip_Legs (trip_id, sequence_number, sequence_order, start_country, start_city, end_country, end_city)
                VALUES (
                    v_trip_id, 
                    leg_idx, 
                    leg_idx, 
                    v_countries[1 + mod(leg_idx, 6)], 
                    v_cities[1 + mod(leg_idx, 6)],
                    v_countries[1 + mod(leg_idx + 1, 6)], 
                    v_cities[1 + mod(leg_idx + 1, 6)]
                ) RETURNING leg_id INTO v_leg_id;

                -- 5. Each trip leg has 0-5 Travelers (from the user's traveler pool)
                -- We limit this by the actual number of travelers the user has
                v_travelers_in_trip := floor(random() * (LEAST(5, v_traveler_count) + 1));
                
                FOR i IN 1..v_travelers_in_trip LOOP
                    INSERT INTO Traveler_Leg_Details (
                        leg_id, traveler_id, travel_mode, departure_time, arrival_time, departure_timezone, arrival_timezone
                    ) VALUES (
                        v_leg_id, 
                        v_current_traveler_ids[i], 
                        'FLIGHT', 
                        NOW(), 
                        NOW() + INTERVAL '2 hours', 
                        'UTC', 
                        'UTC'
                    ) ON CONFLICT DO NOTHING;
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;
