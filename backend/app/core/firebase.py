import os
import logging
import firebase_admin
from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)

# Search for credential file via env var or common fallback names
CREDENTIALS_PATH = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", None)
if not CREDENTIALS_PATH:
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
    fallback_paths = [
        os.path.join(base_dir, "firebase-adminsdk.json"),
        os.path.join(base_dir, "familly-guard-firebase-adminsdk-fbsvc-a575439e25.json")
    ]
    for path in fallback_paths:
        if os.path.exists(path):
            CREDENTIALS_PATH = path
            break

def init_firebase():
    if not firebase_admin._apps:
        if CREDENTIALS_PATH and os.path.exists(CREDENTIALS_PATH):
            try:
                cred = credentials.Certificate(CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin: {e}")
        else:
            logger.warning("firebase-adminsdk.json not found. Push notifications will be mocked.")

def send_push_notification(token: str, title: str, body: str, data: dict = None):
    if not token:
        logger.warning("No FCM token provided. Skipping notification.")
        return False
        
    if not CREDENTIALS_PATH or not os.path.exists(CREDENTIALS_PATH):
        logger.info(f"[MOCK PUSH] To: {token} | Title: {title} | Body: {body} | Data: {data}")
        return True

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        logger.info(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        logger.error(f"Error sending message: {e}")
        return False
