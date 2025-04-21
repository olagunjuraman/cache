import os
import logging
from flask import Flask, request, jsonify
from google.cloud import pubsub_v1
from google.cloud.sql.connector import Connector  
import sqlalchemy
from google.cloud import secretmanager


logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)


PROJECT_ID = os.environ.get("PROJECT_ID")
DB_USER = os.environ.get("DB_USER")
DB_NAME = os.environ.get("DB_NAME")
DB_INSTANCE_CONNECTION_NAME = os.environ.get("DB_INSTANCE_CONNECTION_NAME")
DB_PASSWORD_SECRET_ID = os.environ.get("DB_PASSWORD_SECRET_ID", "db-password") 
DB_PASSWORD_SECRET_VERSION = os.environ.get("DB_PASSWORD_SECRET_VERSION", "latest")
PUBSUB_TOPIC_ID = os.environ.get("PUBSUB_TOPIC_ID")

def get_db_password():
    """Retrieves the database password from Secret Manager."""
    try:
        client = secretmanager.SecretManagerServiceClient()
        secret_name = f"projects/{PROJECT_ID}/secrets/{DB_PASSWORD_SECRET_ID}/versions/{DB_PASSWORD_SECRET_VERSION}"
        response = client.access_secret_version(request={"name": secret_name})
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logging.error(f"Error accessing secret manager: {e}")
        raise

# Initialize Database connection pool
def init_connection_pool() -> sqlalchemy.engine.base.Engine:
    """Initializes a connection pool for Cloud SQL."""
    if not all([PROJECT_ID, DB_USER, DB_NAME, DB_INSTANCE_CONNECTION_NAME, DB_PASSWORD_SECRET_ID]):
        logging.error("Missing database configuration environment variables.")
        return None

    try:
        db_password = get_db_password()
        connector = Connector()

        def getconn() -> sqlalchemy.engine.base.Connection:
            conn = connector.connect(
                DB_INSTANCE_CONNECTION_NAME,
                "pg8000",
                user=DB_USER,
                password=db_password,
                db=DB_NAME,
                ip_type="private" 
            )
            return conn

        pool = sqlalchemy.create_engine(
            "postgresql+pg8000://",
            creator=getconn,
            pool_size=5,
            max_overflow=2,
            pool_timeout=30,  
            pool_recycle=1800,  
        )
        pool.dialect.description_encoding = None
        return pool
    except Exception as e:
        logging.error(f"Error initializing database connection pool: {e}")
        return None

db_pool = init_connection_pool()

# Initialize Pub/Sub Publisher Client
publisher = None
if PROJECT_ID and PUBSUB_TOPIC_ID:
    try:
        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(PROJECT_ID, PUBSUB_TOPIC_ID)
        logging.info(f"Pub/Sub publisher initialized for topic: {topic_path}")
    except Exception as e:
        logging.error(f"Error initializing Pub/Sub client: {e}")
else:
    logging.warning("Pub/Sub environment variables not fully set. Publisher not initialized.")

@app.route('/health')
def health():
    """Basic health check endpoint."""
    logging.info("Health check requested.")
    return jsonify({"status": "ok"}), 200

@app.route('/message', methods=['POST'])
def post_message():
    """Receives a message, writes to Pub/Sub and DB."""
    data = request.get_json()
    if not data or 'message' not in data:
        logging.warning("Received invalid message format.")
        return jsonify({"error": "Invalid request. 'message' field required."}), 400

    message_content = data['message']
    logging.info(f"Received message: {message_content}")

    # 1. Publish to Pub/Sub
    if publisher and topic_path:
        try:
            future = publisher.publish(topic_path, message_content.encode('utf-8'))
            future.result() # Wait for publish to complete
            logging.info(f"Message published to {topic_path}")
        except Exception as e:
            logging.error(f"Failed to publish message to Pub/Sub: {e}")
            # Continue to DB insert even if Pub/Sub fails for now
    else:
        logging.warning("Pub/Sub publisher not available. Skipping publish.")

    # 2. Insert into PostgreSQL
    if db_pool:
        try:
            with db_pool.connect() as db_conn:
                db_conn.execute(sqlalchemy.text(
                    "CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, content TEXT NOT NULL, timestamp TIMESTAMPTZ DEFAULT NOW());"
                ))
                # Insert the message
                insert_stmt = sqlalchemy.text("INSERT INTO messages (content) VALUES (:content)")
                db_conn.execute(insert_stmt, parameters={"content": message_content})
                db_conn.commit()
                logging.info("Message inserted into database.")
        except Exception as e:
            logging.error(f"Failed to insert message into database: {e}")
            return jsonify({"error": "Database operation failed."}), 500
    else:
        logging.error("Database pool not available. Skipping insert.")
        return jsonify({"error": "Database not configured."}), 500

    return jsonify({"status": "message processed"}), 201

if __name__ == '__main__':
    # Use Gunicorn in production via Dockerfile CMD
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))