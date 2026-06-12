import { useEffect, useRef } from 'react';
import { toast } from 'sonner';

export function useWebSocket() {
  const ws = useRef<WebSocket | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return;

    try {
      // Decode JWT to get parent_id (sub)
      const payloadBase64 = token.split('.')[1];
      const decodedPayload = JSON.parse(atob(payloadBase64));
      const parentId = decodedPayload.sub;

      if (!parentId) return;

      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000/api/v1";
      const wsUrlBase = apiUrl.replace(/^http/, 'ws');
      const wsUrl = `${wsUrlBase}/ws/${parentId}?token=${token}`;
      ws.current = new WebSocket(wsUrl);

      ws.current.onopen = () => {
        console.log('WebSocket connected');
      };

      ws.current.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          
          if (data.type === 'SOS_TRIGGERED') {
            if ("Notification" in window && Notification.permission === "granted") {
              new Notification("Alerte SOS - FamilyGuard", {
                body: `Alerte SOS de ${data.profile_name} !`,
                icon: "/favicon.ico"
              });
            }
            
            toast.error(`Alerte SOS de ${data.profile_name} !`, {
              description: data.message,
              duration: Number.POSITIVE_INFINITY, // Require manual dismiss
              icon: '🚨',
              style: {
                backgroundColor: '#EF4444',
                color: 'white',
                border: 'none',
                padding: '16px',
                fontSize: '16px',
              },
              action: {
                label: 'Compris',
                onClick: () => console.log('SOS Acknowledged'),
              },
            });
          } else if (data.type === 'WEB_BLOCKED') {
            toast.warning(`Navigation bloquée (${data.profile_name})`, {
              description: data.message,
              duration: 5000,
            });
          }
        } catch (e) {
          console.error("Invalid WS message", e);
        }
      };

      ws.current.onclose = () => {
        console.log('WebSocket disconnected');
      };

    } catch (error) {
      console.error("Error setting up WebSocket:", error);
    }

    return () => {
      if (ws.current) {
        ws.current.close();
      }
    };
  }, []);
}
