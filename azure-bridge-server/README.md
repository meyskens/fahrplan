# Azure Speech Bridge Server

A WebSocket bridge server for Azure Speech Service that bridges the Dart WebSocket client to the Azure Speech SDK.

## Installation

```bash
cd azure-bridge-server
npm install
```

## Running

```bash
npm start
```

The server will listen on port 3000 by default. You can set a custom port:

```bash
PORT=8080 npm start
```

## Usage

### 1. Connect to WebSocket

Connect to `ws://your-server:3000`

### 2. Send Configuration

Send a JSON message with your Azure credentials:

```json
{
  "cmd": "config",
  "key": "your-azure-subscription-key",
  "region": "francecentral",
  "language": "en-US"
}
```

### 3. Stream Audio

Send raw PCM audio data as binary frames:
- Format: PCM 16-bit signed little-endian
- Sample rate: 16000 Hz
- Channels: 1 (mono)

### 4. Receive Results

The server sends JSON messages:

**Partial results (real-time):**
```json
{"type": "partial", "text": "hello wor"}
```

**Final results:**
```json
{"type": "final", "text": "hello world"}
```

**Status messages:**
```json
{"type": "started"}
{"type": "canceled", "reason": "...", "details": "..."}
{"type": "sessionStopped"}
```

### 5. Stop Recognition

```json
{"cmd": "stop"}
```


