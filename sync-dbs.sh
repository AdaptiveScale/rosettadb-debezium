#!/bin/bash

docker compose -f docker-compose.yaml up -d

# Wait for Kafka Connect to be ready
until $(curl --output /dev/null --silent --head --fail http://localhost:8083/connectors/); do
    printf '.'
    sleep 5
done

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to start..."
until pg_isready -h localhost -p 5432; do
  sleep 5
done

sleep 10

echo "PostgreSQL is ready. Dropping table..."
# Drop the table
PGPASSWORD=postgres psql -h localhost -U postgres -d postgres -c "DROP TABLE IF EXISTS inventory.customers CASCADE; DROP EXTENSION IF EXISTS postgis CASCADE; DROP SCHEMA inventory CASCADE; CREATE SCHEMA inventory;"
echo "Table 'customers' in schema 'inventory' dropped successfully."

bash ./schema_change.sh

curl -i -X POST http://localhost:8083/connectors/ \
  -H "Accept:application/json" \
  -H  "Content-Type:application/json" \
  -d \
'{
    "name": "inventory-connector-from-mysql",
    "config": {
        "connector.class": "io.debezium.connector.mysql.MySqlConnector",
        "tasks.max": "1",
        "database.hostname": "mysql",
        "database.port": "3306",
        "database.user": "debezium",
        "database.password": "dbz",
        "database.server.id": "184054",
        "topic.prefix": "from_mysql",
        "table.include.list": "inventory.customers",
        "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
        "schema.history.internal.kafka.topic": "schema-changes.inventory",
        "transforms": "route",
        "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
        "transforms.route.regex": "([^.]+)\\.([^.]+)\\.([^.]+)",
        "transforms.route.replacement": "from_mysql_$3"
    }
}'


curl -i -X POST http://localhost:8083/connectors/ \
  -H "Accept:application/json" \
  -H "Content-Type:application/json" \
  -d \
'{
    "name": "jdbc-sink-to-postgres2",
    "config": {
        "connector.class": "io.debezium.connector.jdbc.JdbcSinkConnector",
        "topics": "from_mysql_customers",
        "connection.url": "jdbc:postgresql://postgres-target:5432/postgres?currentSchema=inventory",
        "connection.username": "postgres",
        "connection.password": "postgres",
        "auto.create": "true",
        "insert.mode": "upsert",
        "delete.enabled": "true",
        "primary.key.fields": "id",
        "primary.key.mode": "record_key",
        "table.name.format": "customers",
        "schema.evolution": "none"
    }
}'


nohup python3 pause_on_schema_change.py > pause_on_schema_change.log 2>&1 &