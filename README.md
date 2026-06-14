# BikeAI Analyzer — AI-Powered Bike Riding Analysis System

A production-grade system combining **computer vision**, **sensor fusion**, and **real-time AI analysis** to monitor, score, and improve motorcycle/bike riding safety.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App (Android)                     │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │  Dashboard  │  │ Ride History │  │   Reports & Export     │  │
│  └──────┬──────┘  └──────┬───────┘  └──────────┬─────────────┘  │
│         │                │                      │               │
│  ┌──────▼──────────────────────────────────────▼─────────────┐  │
│  │              State Management (Riverpod)                   │  │
│  └──────┬──────────────────────────────────────┬─────────────┘  │
│         │                                      │               │
│  ┌──────▼──────┐  ┌──────────────┐  ┌─────────▼───────────┐  │
│  │  WebSocket  │  │Sensor Fusion │  │   Local SQLite DB    │  │
│  │  Client     │  │Accel+Gyro+GPS│  │   (Ride History)     │  │
│  └──────┬──────┘  └──────┬───────┘  └─────────────────────┘  │
└─────────┼────────────────┼────────────────────────────────────┘
          │                │
          │ WiFi/4G        │ Sensor Data
          ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FastAPI Backend (Python)                      │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
│  │  WebSocket  │  │ REST API     │  │   Report Generator     │  │
│  │  Handler    │  │ /rides /anal │  │   PDF + Charts         │  │
│  └──────┬──────┘  └──────┬───────┘  └──────────┬─────────────┘  │
│         │                │                      │               │
│  ┌──────▼──────────────────────────────────────▼─────────────┐  │
│  │              Service Layer                                  │  │
│  │  ┌──────────┐ ┌────────────┐ ┌──────────┐ ┌────────────┐  │  │
│  │  │YOLOv8    │ │ Behavior   │ │ Sensor   │ │  Score     │  │  │
│  │  │Detector  │ │ Analyzer   │ │ Fusion   │ │ Calculator │  │  │
│  │  └──────────┘ └────────────┘ └──────────┘ └────────────┘  │  │
│  └─────────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │              OpenCV Video Processor                          │  │
│  └─────────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                 SQLAlchemy + SQLite/PostgreSQL                │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          ▲
          │ RTSP/MJPEG Stream
          │
┌─────────┴───────────────┐
│    Action Camera         │
│  (GoPro/DJI/Insta360)  │
│  WiFi Hotspot Mode      │
└─────────────────────────┘
```

---

## Features

### AI Detection (YOLOv8 + OpenCV)
- Cars, bikes, trucks, pedestrians, traffic lanes
- Real-time object tracking with DeepSORT
- Traffic density estimation
- Lane departure detection

### Behavior Analysis
| Behavior | Detection Method |
|----------|-----------------|
| Speeding | GPS speed + optical flow |
| Zig-zag riding | Gyroscope Z-axis variance |
| Hard braking | Accelerometer X-axis spike |
| Unsafe distance | YOLO bounding box + depth estimation |
| Dangerous overtaking | Lateral movement + oncoming vehicle |
| Cornering stability | Gyroscope + accelerometer fusion |
| Traffic handling | Context-aware density analysis |
| Riding smoothness | Jerk calculation from acceleration |

### Scoring System
- **Skill Score** (0–100): Composite riding competence
- **Danger Score** (0–100): Accumulated risk level
- **Safety Rating** (A–F): Overall safety grade
- **Aggression Score**: Braking harshness + acceleration patterns
- **Accident Probability** (%): ML-based risk prediction

### Riding Context Detection
- City traffic riding
- Highway riding
- Empty road riding
- Traffic jam crawling

### Voice Alerts (TTS)
- "Slow down — speed limit exceeded"
- "Unsafe overtaking detected"
- "Hard braking detected — maintain distance"
- "Vehicle too close ahead"
- "Zig-zag pattern detected"

---

## Project Structure

```
bike-ai-analyzer/
├── backend/                    # Python FastAPI server
│   ├── main.py                 # App entrypoint
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── core/
│   │   ├── config.py           # Settings & env vars
│   │   ├── database.py         # SQLAlchemy async setup
│   │   └── dependencies.py     # DI providers
│   ├── models/
│   │   ├── ride.py             # SQLAlchemy ride model
│   │   └── event.py            # SQLAlchemy event model
│   ├── schemas/
│   │   ├── ride.py             # Pydantic schemas
│   │   └── analysis.py         # Analysis response schemas
│   ├── services/
│   │   ├── video_processor.py  # OpenCV frame processing
│   │   ├── object_detector.py  # YOLOv8 detection
│   │   ├── behavior_analyzer.py# Riding behavior analysis
│   │   ├── score_calculator.py # Score computation
│   │   └── sensor_fusion.py    # Kalman filter fusion
│   ├── api/
│   │   └── routes/
│   │       ├── rides.py        # Ride CRUD APIs
│   │       ├── analysis.py     # Analysis endpoints
│   │       ├── stream.py       # WebSocket handler
│   │       └── reports.py      # PDF report generation
│   └── migrations/
│       └── env.py
│
└── mobile/                     # Flutter Android app
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart
    │   ├── core/
    │   │   ├── theme/app_theme.dart
    │   │   ├── constants/app_constants.dart
    │   │   └── utils/formatters.dart
    │   ├── models/
    │   │   ├── ride_model.dart
    │   │   ├── event_model.dart
    │   │   ├── sensor_data.dart
    │   │   └── analysis_result.dart
    │   ├── services/
    │   │   ├── websocket_service.dart
    │   │   ├── camera_service.dart
    │   │   ├── sensor_service.dart
    │   │   ├── tts_service.dart
    │   │   ├── database_service.dart
    │   │   └── report_service.dart
    │   ├── providers/
    │   │   ├── ride_provider.dart
    │   │   └── settings_provider.dart
    │   └── features/
    │       ├── dashboard/
    │       │   ├── dashboard_screen.dart
    │       │   └── widgets/
    │       │       ├── speed_gauge.dart
    │       │       ├── score_card.dart
    │       │       ├── warning_banner.dart
    │       │       ├── camera_preview_widget.dart
    │       │       └── detected_objects_overlay.dart
    │       ├── ride_history/
    │       │   ├── ride_history_screen.dart
    │       │   └── ride_detail_screen.dart
    │       ├── reports/
    │       │   └── report_screen.dart
    │       ├── camera/
    │       │   └── camera_setup_screen.dart
    │       └── settings/
    │           └── settings_screen.dart
    └── android/
        └── app/src/main/AndroidManifest.xml
```

---

## Installation

### Prerequisites
- Python 3.10+
- Flutter 3.16+
- Android Studio / Android SDK
- CUDA-compatible GPU (optional, for YOLOv8 acceleration)
- Action camera with WiFi (GoPro Hero, DJI Action, Insta360, etc.)

---

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Download YOLOv8 model (auto-downloads on first run)
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Initialize database
python -c "
import asyncio
from core.database import init_db
asyncio.run(init_db())
"

# Start the server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Or with Docker:
docker-compose up --build
```

### Backend Environment Variables (.env)
```env
DATABASE_URL=sqlite+aiosqlite:///./bikeai.db
SECRET_KEY=your-secret-key-here
YOLO_MODEL=yolov8n.pt
CAMERA_RTSP_URL=rtsp://192.168.0.1:554/live
MAX_FPS=15
CONFIDENCE_THRESHOLD=0.5
CORS_ORIGINS=["*"]
```

---

### Flutter App Setup

```bash
cd mobile

# Get dependencies
flutter pub get

# Generate Riverpod code
dart run build_runner build

# Run on connected Android device
flutter run

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### Android Permissions
All required permissions are declared in `android/app/src/main/AndroidManifest.xml`:
- `INTERNET` — Backend communication
- `CAMERA` — Phone camera access
- `ACCESS_FINE_LOCATION` — GPS tracking
- `ACCESS_BACKGROUND_LOCATION` — Background GPS
- `HIGH_SAMPLING_RATE_SENSORS` — IMU access
- `BLUETOOTH` / `BLUETOOTH_CONNECT` — Future intercom support
- `FOREGROUND_SERVICE` — Background ride tracking
- `WAKE_LOCK` — Prevent screen sleep during rides

---

## Camera Connection

### WiFi (Recommended)
1. Enable WiFi hotspot on action camera (GoPro, DJI, etc.)
2. Connect Android phone to camera WiFi
3. In the app: Settings → Camera → WiFi RTSP
4. Enter RTSP URL: `rtsp://10.5.5.9:554/live` (GoPro default)
5. Tap "Test Connection"

### Common Camera RTSP URLs
| Camera | URL |
|--------|-----|
| GoPro Hero 8+ | `rtsp://10.5.5.9:554/live` |
| DJI Action 3 | `rtsp://192.168.2.1:554/live` |
| Insta360 | `rtsp://192.168.42.1:554/live` |
| Generic IP Cam | `rtsp://192.168.1.X:554/stream` |

---

## API Reference

### REST Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/rides` | Start new ride |
| GET | `/api/rides` | List all rides |
| GET | `/api/rides/{id}` | Get ride details |
| PUT | `/api/rides/{id}/end` | End current ride |
| DELETE | `/api/rides/{id}` | Delete ride |
| GET | `/api/analysis/summary/{ride_id}` | Get ride summary |
| POST | `/api/analysis/frame` | Analyze single frame |
| GET | `/api/reports/{ride_id}` | Download PDF report |
| GET | `/api/reports/{ride_id}/json` | Get JSON report |

### WebSocket
```
ws://your-server:8000/ws/stream/{session_id}
```

**Client → Server (JSON):**
```json
{
  "type": "sensor_data",
  "timestamp": 1700000000000,
  "accelerometer": {"x": 0.1, "y": 9.8, "z": 0.2},
  "gyroscope": {"x": 0.01, "y": 0.02, "z": 0.1},
  "gps": {"lat": 28.6139, "lon": 77.2090, "speed": 45.2, "heading": 180.0}
}
```

**Client → Server (Binary):** JPEG-encoded video frame

**Server → Client (JSON):**
```json
{
  "type": "analysis_result",
  "timestamp": 1700000000000,
  "speed": 45.2,
  "skill_score": 78,
  "danger_score": 22,
  "safety_rating": "B",
  "detected_objects": [
    {"class": "car", "confidence": 0.91, "bbox": [100, 150, 200, 300], "distance_m": 12.5}
  ],
  "warnings": ["UNSAFE_DISTANCE"],
  "riding_context": "CITY_TRAFFIC",
  "aggression_score": 35,
  "accident_probability": 0.08
}
```

---

## Scoring Details

### Skill Score (0–100)
```
Skill Score = 100 - penalties

Penalties:
- Hard braking event:      -3 points
- Unsafe distance:         -5 points
- Zig-zag pattern:         -4 points
- Lane departure:          -3 points
- Dangerous overtaking:    -6 points
- Speeding (>20% over):    -4 points
```

### Danger Score (0–100)
```
Danger Score = weighted sum of risk factors

Factors (weighted):
- Speed (30%):          speed / speed_limit
- Following distance:   1 - (distance / safe_distance)
- Traffic density:      objects_in_frame / max_objects
- Behavior events:      recent_events * event_weight
```

### Safety Rating (A–F)
| Score | Rating |
|-------|--------|
| 90–100 | A (Excellent) |
| 75–89  | B (Good) |
| 60–74  | C (Average) |
| 40–59  | D (Poor) |
| 0–39   | F (Dangerous) |

---

## Advanced Features

### Ride Context Detection
The system automatically detects riding context based on:
- GPS speed profile
- Traffic density (YOLO object count)
- Road curvature (gyroscope)
- Time of day

| Context | Speed | Traffic | Description |
|---------|-------|---------|-------------|
| CITY_TRAFFIC | <40 km/h | High | Stop-and-go |
| HIGHWAY | >80 km/h | Low | Open road |
| EMPTY_ROAD | Any | None | Rural/open |
| TRAFFIC_JAM | <10 km/h | Very High | Congestion |

### Ride Replay
Saved rides include timestamped events. The replay screen shows:
- Speed timeline with highlighted danger moments
- Event markers (tap to see details)
- Score evolution over the ride

### Accident Probability Model
Inputs:
- Current speed vs. context speed limit
- Distance to nearest vehicle
- Recent behavior events (last 30s)
- Road surface context
- Time of day

---

## Future Roadmap

### v1.1 — Helmet Intercom
- Bluetooth LE connection to Cardo/Sena helmet intercoms
- Audio alerts directly to helmet speakers
- Two-way voice feedback

### v1.2 — Cloud Sync
- Ride data sync to cloud dashboard
- Fleet management for multiple riders
- Insurance integration API

### v1.3 — Advanced AI
- Custom YOLOv8 model fine-tuned on Indian traffic
- Pothole detection
- Road sign recognition
- Weather-adjusted scoring

### v2.0 — Edge AI
- TensorFlow Lite model running entirely on phone
- No backend required for basic analysis
- Offline mode with sync when connected

---

## Performance Optimization

### Battery Saving
- Adaptive FPS: reduces to 5fps when no movement detected
- GPS batching: 1Hz updates vs. continuous
- Background service: efficient foreground service
- Screen dimming: auto-dim after 30s of stable riding

### Processing
- YOLOv8 Nano model for mobile-speed inference
- JPEG compression at 70% for stream frames
- Frame skip: process every 3rd frame at high speed
- Kalman filter for smooth sensor data

---

## Deployment

### Self-hosted (Raspberry Pi / Server)
```bash
docker-compose up -d
```

### Cloud (AWS/GCP/Azure)
```bash
# Build and push image
docker build -t bikeai-backend .
docker tag bikeai-backend your-registry/bikeai-backend:latest
docker push your-registry/bikeai-backend:latest

# Deploy to container service
# Update CORS_ORIGINS in .env with your domain
```

---

## License
MIT License — See LICENSE file for details.

## Contributing
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes
4. Push and open a Pull Request
