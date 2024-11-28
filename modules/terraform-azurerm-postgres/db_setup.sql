-- Create tables
CREATE TABLE IF NOT EXISTS payee (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) NOT NULL
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES payee(user_id),
    transaction_amount DECIMAL(10, 2) NOT NULL,
    merchant VARCHAR(255) NOT NULL,
    country VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS fraud_scores (
    score_id SERIAL PRIMARY KEY,
    transaction_id INT REFERENCES transactions(transaction_id),
    user_id INT REFERENCES payee(user_id),
    fraud_score DECIMAL(5, 2) NOT NULL,
    risk_level VARCHAR(50) NOT NULL
);
-- Add other schema creation or data insertion statements as needed
