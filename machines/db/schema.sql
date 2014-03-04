-- clients
DROP TABLE IF EXISTS clients;
CREATE TABLE clients(id INTEGER PRIMARY KEY,
                     client_number VARCHAR(6),
                     created_at DATETIME);

-- readings
DROP TABLE IF EXISTS readings;
CREATE TABLE readings(id INTEGER PRIMARY KEY, 
                      systolic_pressure REAL,
                      diastolic_pressure REAL,
                      pulse_rate REAL,
                      client_id INTEGER,
                      created_at DATETIME);
                     