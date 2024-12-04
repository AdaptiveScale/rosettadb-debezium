#!/bin/bash

docker compose up -d docker-compose.yaml

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
    "name": "jdbc-sink-to-postgres",
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


nohup python3 pause_on_schema_change.py > /dev/null 2>&1 &