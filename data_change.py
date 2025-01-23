from confluent_kafka import Consumer, KafkaException
import json
import requests



# Configuration for Kafka consumer
KAFKA_BROKER = "localhost:9092"
DEBEZIUM_TOPIC = "from_mysql_customers"

consumer_config = {
    'bootstrap.servers': KAFKA_BROKER,
    'group.id': 'debezium_sql_generator',
    'auto.offset.reset': 'earliest',
}

# Initialize the Kafka Consumer
consumer = Consumer(consumer_config)
consumer.subscribe([DEBEZIUM_TOPIC])

# Function to generate SQL statements based on the Debezium change event
def generate_sql(change_event):
    """Generate SQL statements based on the Debezium change event."""
    payload = change_event.get('payload', {})
    op = payload.get('op')  # Operation type: c = create, u = update, d = delete

    print(payload)
    table = payload.get('source', {}).get('table')
    if not table:
        return "Error: Table name not found."

    if op == 'c' or op == 'r':  # Insert
        after = payload.get('after', {})
        columns = ', '.join(after.keys())
        values = ', '.join(f"'{value}'" if isinstance(value, str) else str(value) for value in after.values())
        return f"INSERT INTO {table} ({columns}) VALUES ({values});"

    elif op == 'u':  # Update
        before = payload.get('before', {})
        after = payload.get('after', {})
        set_clauses = ', '.join(f"{key} = '{value}'" if isinstance(value, str) else f"{key} = {value}"
                                for key, value in after.items() if before.get(key) != value)
        where_clauses = ' AND '.join(f"{key} = '{value}'" if isinstance(value, str) else f"{key} = {value}"
                                     for key, value in before.items())
        return f"UPDATE {table} SET {set_clauses} WHERE {where_clauses};"

    elif op == 'd':  # Delete
        before = payload.get('before', {})
        where_clauses = ' AND '.join(f"{key} = '{value}'" if isinstance(value, str) else f"{key} = {value}"
                                     for key, value in before.items())
        return f"DELETE FROM {table} WHERE {where_clauses};"

    else:
        return "Unsupported operation."

try:
    # Test Kafka connection
    metadata = consumer.list_topics(timeout=10)
    print("Connected to Kafka successfully.")

    # Poll messages from Kafka
    while True:
        msg = consumer.poll(1.0)  # Polling interval in seconds

        if msg is None:
            continue
        if msg.error():
            if msg.error().code() == KafkaException._PARTITION_EOF:
                continue
            else:
                print(f"Kafka error: {msg.error()}")
                break

        try:
            # Parse the message value
            change_event = json.loads(msg.value().decode('utf-8'))
            print(change_event)
            sql_statement = generate_sql(change_event)
            
            sql_statement = sql_statement.replace('None', 'NULL')
            print(sql_statement)

            kinetica_url = "http://localhost:9191"
            username = "admin"
            password = "Admin123!"

            # Define the data payload
            data = {
                "statement": sql_statement,
                "encoding": "json",
                "options": {
                    "current_schema": "inventory"
                }
            }

            # Set headers
            headers = {
                "Content-Type": "application/json"
            }

            # Make the POST request
            response = requests.post(
                kinetica_url + '/execute/sql', 
                headers=headers, 
                data=json.dumps(data),
                auth = (username, password)
            )

            # Print the response
            print(response.status_code)
            print(response.json()) # Print the response body
        except Exception as e:
            print(f"Failed to process message: {msg.value()}, error: {e}")

except Exception as e:
    print(f"Unexpected error: {e}")

finally:
    consumer.close()
    print("Consumer closed.")