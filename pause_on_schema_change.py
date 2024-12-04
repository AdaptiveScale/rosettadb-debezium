import json
import time
import requests
import subprocess
from confluent_kafka import Consumer, KafkaError

# Configuration
KAFKA_BROKER = "localhost:9092"
DEBEZIUM_TOPIC = "schema-changes.inventory"  # Replace with your Debezium topic
CONNECTOR_NAME = "jdbc-sink-to-postgres"     # Replace with your connector name
KAFKA_CONNECT_URL = "http://localhost:8083/connectors"
PAUSE_DURATION = 60  # Time to pause the connector (in seconds)

# Configure Kafka consumer
consumer_conf = {
    'bootstrap.servers': KAFKA_BROKER,
    'group.id': 'schema-change-listener',
    'auto.offset.reset': 'latest'
}
consumer = Consumer(consumer_conf)
consumer.subscribe([DEBEZIUM_TOPIC])

# Functions to pause and resume the Kafka Connect connector
def pause_connector():
    print(f"Pausing connector: {CONNECTOR_NAME}")
    response = requests.put(f"{KAFKA_CONNECT_URL}/{CONNECTOR_NAME}/pause")
    if response.status_code == 202:
        print("Connector paused successfully.")
    else:
        print("Failed to pause connector.")

def resume_connector():
    print(f"Resuming connector: {CONNECTOR_NAME}")
    response = requests.put(f"{KAFKA_CONNECT_URL}/{CONNECTOR_NAME}/resume")
    if response.status_code == 202:
        print("Connector resumed successfully.")
    else:
        print("Failed to resume connector.")

# Kafka consumer loop to detect schema changes
print(f"Listening for schema change events on topic: {DEBEZIUM_TOPIC}")

try:
    while True:
        msg = consumer.poll(1.0)  # Poll with a 1-second timeout
        if msg is None:
            continue  # No message received, continue polling
        if msg.error():
            if msg.error().code() != KafkaError._PARTITION_EOF:
                print(f"Error: {msg.error()}")
            continue

        # Decode and process the message
        message = msg.value().decode('utf-8')
        print(f"Received message: {message}")

        try:
            data = json.loads(message)
        except json.JSONDecodeError:
            print("Invalid JSON received")
            continue

        # Check if the message contains a schema change ("ddl" field)
        if "ddl" in data:
            ddl_statement = data["ddl"]
            print(f"Detected schema change: {ddl_statement}")

            # Pause the connector
            pause_connector()

            # Wait for the specified duration to handle the schema change
            print(f"Waiting for rosetta for schema handling...")

            # Run the script
            result = subprocess.run(['bash', 'schema_change.sh'], capture_output=True, text=True)

            # Print the output and errors
            print("Output:", result.stdout)
            print("Error:", result.stderr)
            print("Return Code:", result.returncode)

            # Resume the connector
            resume_connector()

except KeyboardInterrupt:
    print("Shutting down...")

finally:
    consumer.close()