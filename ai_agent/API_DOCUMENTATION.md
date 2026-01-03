# HKU Library Booking Agent API Documentation

## Overview

This API provides an AI-powered booking agent service for HKU Library room reservations. The service supports multiple concurrent users through session-based architecture, where each user maintains an isolated conversation and booking state.

## Base Information

- **Base URL**: `http://localhost:8000`
- **Protocol**: HTTP
- **Content-Type**: `application/json`
- **Method**: All endpoints use `POST`

## API Endpoints

### 1. Create Session

Create a new booking session for a user. Each session maintains isolated agent state and conversation history.

**Endpoint**: `POST /tools/create_session`

**Request Body**:
```json
{
  "arguments": {
    "github_token": "string (required)",
    "user_id": "string (optional)"
  }
}
```

**Parameters**:
- `github_token`: GitHub personal access token for AI model access (required)
- `user_id`: Optional identifier for tracking purposes

**Response**:
```json
{
  "session_id": "uuid-string",
  "status": "success",
  "message": "Session created successfully. Session will expire after 30 minutes of inactivity."
}
```

**Example**:
```javascript
const response = await fetch('http://localhost:8000/tools/create_session', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    arguments: {
      github_token: "ghp_xxxxxxxxxxxxx",
      user_id: "user123"
    }
  })
});
const { session_id } = await response.json();
```

---

### 2. Chat with Agent

Send a message to the booking agent within a specific session. The agent will collect booking information through conversation and execute bookings when all required information is gathered.

**Endpoint**: `POST /tools/chat_with_agent`

**Request Body**:
```json
{
  "arguments": {
    "session_id": "string (required)",
    "message": "string (required)"
  }
}
```

**Parameters**:
- `session_id`: Unique session identifier from `create_session`
- `message`: User's message to the agent

**Response**:
```json
{
  "status": "success",
  "response": "Agent's reply message",
  "collected_info": {
    "location": "5",
    "type": "29",
    "rooms": [258, 259, 260],
    "date": "20251230",
    "sessions": ["14001500", "15001600"]
  }
}
```

**Error Response**:
```json
{
  "status": "error",
  "message": "Invalid or expired session. Please create a new session using create_session."
}
```

**Example**:
```javascript
const response = await fetch('http://localhost:8000/tools/chat_with_agent', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    arguments: {
      session_id: sessionId,
      message: "I want to book a study room at Chi Wah tomorrow 2PM"
    }
  })
});
const result = await response.json();
console.log(result.response); // Agent's reply
console.log(result.collected_info); // Current booking information
```

---

### 3. Get Session Status

Retrieve the current status and collected information from a session.

**Endpoint**: `POST /tools/get_session_status`

**Request Body**:
```json
{
  "arguments": {
    "session_id": "string (required)"
  }
}
```

**Response**:
```json
{
  "status": "success",
  "session_id": "uuid-string",
  "user_id": "user123",
  "created_at": "2025-12-29T10:30:00",
  "last_activity": "2025-12-29T10:35:00",
  "session_age_minutes": 5,
  "idle_time_minutes": 0,
  "collected_info": {
    "location": "5",
    "type": "29",
    "rooms": [258, 259],
    "date": "20251230",
    "sessions": ["14001500"]
  }
}
```

**Example**:
```javascript
const response = await fetch('http://localhost:8000/tools/get_session_status', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    arguments: { session_id: sessionId }
  })
});
const status = await response.json();
```

---

### 4. Reset Session

Reset the booking agent's collected information within a session. Clears all collected booking data but keeps the session active.

**Endpoint**: `POST /tools/reset_session`

**Request Body**:
```json
{
  "arguments": {
    "session_id": "string (required)"
  }
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Session data has been reset. All collected information cleared."
}
```

**Example**:
```javascript
const response = await fetch('http://localhost:8000/tools/reset_session', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    arguments: { session_id: sessionId }
  })
});
```

---

### 5. End Session

Explicitly end a session and clean up resources. Use this when a user is done with booking to free up resources immediately.

**Endpoint**: `POST /tools/end_session`

**Request Body**:
```json
{
  "arguments": {
    "session_id": "string (required)"
  }
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Session ended successfully."
}
```

**Example**:
```javascript
const response = await fetch('http://localhost:8000/tools/end_session', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    arguments: { session_id: sessionId }
  })
});
```

---

### 6. List Active Sessions

List all currently active sessions (for admin/monitoring purposes).

**Endpoint**: `POST /tools/list_active_sessions`

**Request Body**:
```json
{
  "arguments": {}
}
```

**Response**:
```json
{
  "status": "success",
  "active_session_count": 3,
  "sessions": [
    {
      "session_id": "uuid-1",
      "user_id": "user123",
      "created_at": "2025-12-29T10:30:00",
      "idle_minutes": 5
    },
    {
      "session_id": "uuid-2",
      "user_id": "user456",
      "created_at": "2025-12-29T10:32:00",
      "idle_minutes": 2
    }
  ]
}
```

---

## Complete Usage Flow

### Typical User Journey

```
1. User opens the app
   ↓
2. Frontend calls create_session()
   → Receives session_id
   ↓
3. User sends message: "I want to book a study room"
   ↓
4. Frontend calls chat_with_agent(session_id, message)
   → Displays agent's response
   ↓
5. Agent asks: "Which library would you like to book at?"
   ↓
6. User replies: "Chi Wah"
   ↓
7. Frontend calls chat_with_agent(session_id, "Chi Wah")
   ↓
8. (Conversation continues until all info is collected)
   ↓
9. Agent executes booking
   ↓
10. Frontend calls end_session(session_id)
    or session expires automatically after 30 minutes
```

### Code Example (React/React Native)

```javascript
import { useState, useEffect } from 'react';

const BookingChat = () => {
  const [sessionId, setSessionId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  
  const API_BASE = 'http://localhost:8000';
  const GITHUB_TOKEN = 'your-github-token';

  // Create session on component mount
  useEffect(() => {
    const initSession = async () => {
      const response = await fetch(`${API_BASE}/tools/create_session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          arguments: {
            github_token: GITHUB_TOKEN,
            user_id: 'user123'
          }
        })
      });
      const result = await response.json();
      setSessionId(result.session_id);
    };
    
    initSession();
    
    // Cleanup on unmount
    return () => {
      if (sessionId) {
        fetch(`${API_BASE}/tools/end_session`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            arguments: { session_id: sessionId }
          })
        });
      }
    };
  }, []);

  const sendMessage = async () => {
    if (!input.trim() || !sessionId) return;
    
    // Add user message to UI
    setMessages(prev => [...prev, { role: 'user', content: input }]);
    
    // Send to agent
    const response = await fetch(`${API_BASE}/tools/chat_with_agent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        arguments: {
          session_id: sessionId,
          message: input
        }
      })
    });
    
    const result = await response.json();
    
    if (result.status === 'success') {
      // Add agent response to UI
      setMessages(prev => [...prev, { 
        role: 'agent', 
        content: result.response 
      }]);
    } else {
      // Handle error (e.g., session expired)
      console.error(result.message);
    }
    
    setInput('');
  };

  return (
    <div>
      <div className="messages">
        {messages.map((msg, i) => (
          <div key={i} className={msg.role}>
            {msg.content}
          </div>
        ))}
      </div>
      <input 
        value={input} 
        onChange={e => setInput(e.target.value)}
        onKeyPress={e => e.key === 'Enter' && sendMessage()}
      />
      <button onClick={sendMessage}>Send</button>
    </div>
  );
};
```

---

## Session Management

### Session Lifecycle

- **Creation**: Sessions are created via `create_session` and assigned a unique UUID
- **Activity Tracking**: Each API call updates the session's `last_activity` timestamp
- **Timeout**: Sessions automatically expire after **30 minutes** of inactivity
- **Cleanup**: A background task removes expired sessions every **5 minutes**
- **Manual End**: Sessions can be explicitly ended via `end_session`

### Best Practices

1. **Create session once per user**: When user opens the app or starts a new booking flow
2. **Reuse session_id**: Use the same session_id for all messages in one conversation
3. **End session explicitly**: Call `end_session` when user completes or cancels booking
4. **Handle session expiry**: If you receive "Invalid or expired session" error, create a new session
5. **Store session_id securely**: Keep session_id in app state/memory, don't expose in URLs

---

## Error Handling

All endpoints return a response with a `status` field:

- `"success"`: Operation completed successfully
- `"error"`: Operation failed, check `message` field for details

## Support Information

For issues or questions:
- Check session status using `get_session_status`
- Monitor active sessions using `list_active_sessions`
- Review server logs for detailed error information

---

## Version History
- **v1.0.0** (2025-12-29): Initial release with session-based multi-user support
