# LGM Spring Boot Service Manager - Web UI

A modern, responsive web interface for the LGM Spring Boot Service Manager.

## Features

### 🎯 Service Management
- **Real-time Status Monitoring**: Live service status with color-coded indicators
- **Smart Startup Modes**: Auto-detect JAR/Maven, force JAR mode, or force Maven mode
- **Individual Service Controls**: Start, stop, and view logs for each service
- **Bulk Operations**: Start/stop all services with one click

### 🔨 Build Operations
- **Parallel Builds**: Fast parallel git pull and Maven build operations
- **Sequential Builds**: Traditional sequential build process
- **Progress Feedback**: Real-time status updates during operations

### 📊 Monitoring
- **Live Service Status**: Auto-refreshing every 10 seconds
- **Service Logs**: View real-time logs in separate windows
- **JAR Detection**: Visual indicators for services with compiled JARs
- **Scenario Information**: Current run scenario display

### 🎨 Modern Interface
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Beautiful UI**: Modern gradient design with smooth animations
- **Real-time Updates**: Auto-refresh with manual refresh option
- **Accessibility**: Clean, readable interface with proper contrast

## Quick Start

### Prerequisites
- Python 3.6 or higher
- Flask (automatically installed if missing)

### Launch Web UI

```bash
# Option 1: Use the startup script (recommended)
./start_web_ui.sh

# Option 2: Direct Python execution
python3 web_ui.py
```

### Access the Interface
Open your browser and navigate to: **http://localhost:8098**

## Usage

### Service Operations
1. **Start All Services**: Choose from auto-detect, JAR mode, or Maven mode
2. **Individual Services**: Click service-specific buttons for granular control
3. **Stop Services**: Stop individual services or all services at once
4. **View Logs**: Click "📋 Logs" to open real-time log viewer

### Build Operations
1. **Parallel Build**: Fast parallel git pull and Maven compilation
2. **Sequential Build**: Traditional step-by-step build process
3. **Progress Monitoring**: Watch build progress with status updates

### Status Monitoring
- Services automatically refresh every 10 seconds
- Green badges indicate running services
- Red badges indicate stopped services
- "🚀 JAR Available" tags show services ready for fast startup

## Technical Details

### Architecture
- **Backend**: Python Flask web server
- **Frontend**: Vanilla JavaScript with modern CSS
- **Integration**: RESTful API calls to bash script functions
- **Port**: 8098 (configurable in web_ui.py)

### API Endpoints
- `GET /api/status` - Service status information
- `POST /api/service/<name>/start` - Start individual service
- `POST /api/service/<name>/stop` - Stop individual service  
- `POST /api/services/start-all` - Start all services
- `POST /api/services/stop-all` - Stop all services
- `POST /api/build/pull-and-build` - Git pull and build operations
- `GET /api/logs/<name>` - Service log retrieval

### Security Notes
- **Local Only**: Binds to localhost by default for security
- **No Authentication**: Designed for local development use
- **File System Access**: Limited to service manager directory

## Customization

### Change Port
Edit `web_ui.py` and modify the last line:
```python
app.run(host='0.0.0.0', port=8098, debug=False, threaded=True)
```

### Styling
Modify the CSS in `templates/index.html` to customize appearance.

### Add Features
The Flask backend is easily extensible - add new API endpoints and corresponding frontend functionality.

## Troubleshooting

### Flask Not Found
```bash
pip3 install Flask==3.0.0
```

### Permission Denied
```bash
chmod +x start_web_ui.sh
chmod +x web_ui.py
```

### Port Already in Use
Change the port in `web_ui.py` or stop the conflicting process:
```bash
lsof -ti:8098 | xargs kill -9
```

### Service Manager Not Found
Ensure you're running the web UI from the same directory as `service_manager.sh`.

## Development

### File Structure
```
├── web_ui.py              # Flask backend server
├── start_web_ui.sh        # Startup script
├── requirements.txt       # Python dependencies
├── templates/
│   └── index.html        # Frontend interface
└── WEB_UI_README.md      # This documentation
```

### Adding New Features
1. Add API endpoint in `web_ui.py`
2. Add corresponding JavaScript function in `index.html`
3. Update UI elements as needed

## Performance

- **Lightweight**: ~300 lines of Python + single HTML file
- **Fast Response**: Cached status updates (5-second cache)
- **Low Overhead**: Minimal resource usage
- **Concurrent**: Threaded Flask server handles multiple requests

## Compatibility

- **Python**: 3.6+
- **Browsers**: Chrome, Firefox, Safari, Edge (modern versions)
- **Operating Systems**: macOS, Linux (where the service manager runs)
- **Mobile**: Responsive design works on phones and tablets