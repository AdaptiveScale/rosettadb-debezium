# rosettadb-debezium
### Synchronising two databases using RosettaDB and Debezium.
#### Source: MySQL, Target: Postgres

This project demonstrates how to synchronize two databases using two powerful open-source technologies: RosettaDB for Change Schema Capture (CSC) and Debezium for Change Data Capture (CDC). RosettaDB ensures seamless schema migration and transformation between databases, while Debezium tracks and replicates real-time data changes. Together, they provide a robust solution for database synchronization, even when schemas evolve over time.


### Prerequisites

Before starting, ensure you have the following installed and configured:

1.	Docker
  
Used to run containers for RosettaDB, Debezium, and the database instances.

2.	Python 3
 
Required for running utility scripts or interacting with the Debezium Kafka for capturing schema changes.
Install the required Python dependencies using:

```
  pip install requests confluent_kafka
```

### Start

```
./sync-dbs.sh