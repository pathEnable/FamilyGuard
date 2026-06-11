"""
FCM (Firebase Cloud Messaging) push notification service.
Sends push notifications to parent devices via Firebase.
"""
import firebase_admin
from firebase_admin import credentials, messaging
import os

_firebase_initialized = False

def _ensure_firebase():
    """Initialize Firebase Admin SDK if not already done."""
    global _firebase_initialized
    if _firebase_initialized:
        return
    
    cred_path = os.environ.get("FIREBASE_CREDENTIALS_PATH")
    if cred_path and os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    else:
        # Try default credentials (for cloud environments)
        try:
            firebase_admin.initialize_app()
        except ValueError:
            # Already initialized
            pass
    _firebase_initialized = True


def send_push_notification(token: str, title: str, body: str, data: dict = None):
    """
    Send a push notification via FCM.
    
    Args:
        token: The FCM device token of the recipient
        title: Notification title
        body: Notification body text
        data: Optional data payload
    """
    try:
        _ensure_firebase()
        
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        
        response = messaging.send(message)
        print(f"FCM notification sent successfully: {response}")
        return response
    except Exception as e:
        print(f"FCM notification failed: {e}")
        return None
