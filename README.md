# LGM Spring Boot Service Manager

A comprehensive bash-based tool for managing multiple Spring Boot microservices with an interactive terminal UI. This tool provides unified management for development workflows including git operations, Maven builds, and service lifecycle management.

**🔗 Repository**: https://github.com/hdbernd/LGM_Spring_Boot_Manager

> **Latest Update**: Enhanced with separate terminal sessions for each service, ensuring proper network reachability and improved process management.

## 🚀 Features

### Service Operations
- **Start/Stop/Restart** all services or individual services in **separate terminal windows**
- **Real-time status monitoring** with Maven process detection and PID tracking
- **Proper network reachability** - each service runs in its own terminal session
- **Graceful shutdown** with Maven process detection and force-kill fallback

### Build Operations
- **Git pull** for all repositories or individual services
- **Maven clean install** for all projects or individual services
- **Combined pull & build** workflow (equivalent to original `pull_and_build.sh`)
- **Progress tracking** with success/failure counters

### Monitoring & Logging
- **Service status dashboard** with visual indicators
- **Log file management** and viewing
- **Individual service monitoring**
- **Build output tracking**

### Interactive UI
- **Colorful terminal interface** with organized menus
- **Individual service management** with dedicated submenus
- **Real-time status updates**
- **Error handling** with user-friendly messages

## 📁 Project Structure

```
LGM_Pull_Build/
├── folders.txt              # Service directory configuration
├── service_manager.sh       # Interactive terminal UI (main tool)
├── start_services.sh        # Batch start script
├── stop_services.sh         # Batch stop script
├── pull_and_build.sh       # Original git pull & build script
├── pids/                   # Auto-generated PID and log directory
│   ├── *.pid              # Process ID files
│   └── *.log              # Service log files
└── README.md              # This file
```

## 🛠 Setup

### Prerequisites
- **Bash** (macOS/Linux)
- **Git** installed and configured
- **Maven** (`mvn`) available in PATH
- **Java** environment configured for Spring Boot

### Configuration

1. **Clone or download** this repository
2. **Configure service paths** in `folders.txt`:
   ```bash
   # Add your folder paths here, one per line
   /Users/username/Documents/LGM_GIT/master-data-service
   /Users/username/Documents/LGM_GIT/configuration-service
   /Users/username/Documents/LGM_GIT/freight-tendering-service
   # ... add more services
   ```

3. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

## 🎮 Usage

### Interactive Service Manager (Recommended)

Start the main interactive UI:
```bash
./service_manager.sh
```

**Main Menu Options:**

🚀 **Service Operations:**
- `1` - Start all services
- `2` - Stop all services  
- `3` - Restart all services
- `4` - Manage individual services

🔨 **Build Operations:**
- `5` - Git pull all services
- `6` - Clean install all services
- `7` - Pull and build all services

📊 **Monitoring:**
- `8` - View logs
- `9` - Refresh status
- `10` - Exit

### Individual Service Management

Select option `4` from the main menu to access individual service controls:

- **Start/Stop/Restart** specific services
- **Git pull** individual repositories
- **Clean install** specific projects
- **View logs** for individual services
- **Combined pull & build** for single service

### Command Line Scripts

For automation or CI/CD, use the standalone scripts:

```bash
# Start all services in background
./start_services.sh

# Stop all running services
./stop_services.sh

# Traditional pull and build (original workflow)
./pull_and_build.sh
```

## 📊 Service Status Indicators

- 🟢 **Running** - Maven process is active and service is reachable
- 🟡 **Terminal open** - Terminal window exists but Maven may still be starting
- 🔴 **Stopped** - No service process found
- ⚠️ **Stale PID** - PID file exists but process is dead (auto-cleaned)

## 📝 Logging

All service logs are automatically managed:

- **Location**: `pids/` directory
- **Format**: `{service-name}.log`
- **Content**: Complete Spring Boot startup and runtime logs
- **Viewing**: Use option `8` in the UI or check files directly

Example log files:
```
pids/master-data-service.log
pids/configuration-service.log
pids/stock-service.log
```

## 🔧 Configuration Details

### folders.txt Format

```bash
# Comments start with #
# Blank lines are ignored

# Absolute paths to Spring Boot service directories
/Users/username/Documents/LGM_GIT/master-data-service
/Users/username/Documents/LGM_GIT/configuration-service

# Tilde expansion is supported
~/Documents/LGM_GIT/freight-tendering-service
```

### Requirements per Service Directory

Each service directory should contain:
- **`.git/`** - For git pull operations
- **`pom.xml`** - For Maven build operations
- **Spring Boot Maven plugin** configured for `spring-boot:run`

## 🚦 Workflow Examples

### Development Workflow
1. **Pull latest changes**: Option `5` (Git pull all)
2. **Build projects**: Option `6` (Clean install all)
3. **Start services**: Option `1` (Start all services)
4. **Monitor logs**: Option `8` (View logs)

### Quick Start
1. **Pull and build**: Option `7` (Pull and build all)
2. **Start services**: Option `1` (Start all services)

### Individual Service Debug
1. **Individual management**: Option `4`
2. **Select specific service**
3. **Stop service**: Option `2`
4. **Pull and build**: Option `6`
5. **Start service**: Option `1`
6. **View logs**: Option `7`

## 🛡 Error Handling

The tool includes comprehensive error handling:

- **Missing directories** - Warnings with skip logic
- **Non-git repositories** - Graceful skip with notifications  
- **Missing pom.xml** - Build skip with warnings
- **Build failures** - Error reporting with continuation
- **Process management** - Stale PID cleanup and force-kill fallback
- **Terminal compatibility** - Fallback instructions for non-macOS systems
- **Maven process detection** - Multiple strategies for reliable service tracking

## 🔄 Process Management

### Starting Services
- Services run in **separate Terminal.app windows** (macOS) for proper isolation
- **Maven process detection** by service name for accurate tracking
- **PID files** created in `pids/` directory with actual Maven process IDs
- **Individual terminal sessions** ensure proper network binding and reachability
- **Startup scripts** generated per service for consistent launching

### Stopping Services
- **Smart process detection** - finds actual Maven processes by service name
- **Graceful shutdown** using `SIGTERM` on Maven processes
- **15-second timeout** before force kill with `SIGKILL`
- **Automatic cleanup** of PID files and startup scripts
- **Terminal and process verification** to ensure complete termination

## 🎨 UI Features

### Colors and Indicators
- 🔵 **Blue** - Process status and operations
- 🟢 **Green** - Success messages and running status
- 🔴 **Red** - Errors and stopped status
- 🟡 **Yellow** - Warnings and notifications
- 🟣 **Purple** - Section headers and separators
- 🔵 **Cyan** - Information and summaries

### Navigation
- **Number-based menu** selection
- **Enter to continue** prompts
- **Clear status displays**
- **Organized menu sections**

## 📋 Services Included

Based on `folders.txt`, this tool manages the following LGM (Logistics Management) microservices:

1. **master-data-service** - Master data management
2. **configuration-service** - Configuration management
3. **freight-tendering-service** - Freight tendering operations
4. **stock-service** - Stock management
5. **wm-internal-process-service** - Warehouse internal processes
6. **outbound-process-service** - Outbound logistics
7. **transport-execution-service** - Transport execution

## 🔧 Customization

### Adding New Services
1. Add service path to `folders.txt`
2. Ensure service has proper `pom.xml` and git setup
3. Restart service manager - new service appears automatically

### Modifying Colors
Edit color variables at the top of `service_manager.sh`:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
# ... modify as needed
```

### Custom Log Retention
Modify log cleanup in `stop_services.sh`:
```bash
# Comment out this line to keep logs
rm -f "$PID_DIR"/*.log
```

## 🐛 Troubleshooting

### Services Won't Start
- Check if ports are already in use: `lsof -i :8080` (replace with your port)
- Verify Maven and Java installation: `mvn --version` and `java --version`
- Review individual terminal windows for startup errors
- Ensure `pom.xml` has Spring Boot Maven plugin configured
- Check that Terminal.app has necessary permissions on macOS

### Git Pull Failures
- Verify git credentials and repository access
- Check for uncommitted changes requiring stash
- Ensure network connectivity

### Build Failures
- Check Maven settings and dependencies
- Verify Java version compatibility
- Review build logs for specific errors

### Permission Issues
```bash
# Make scripts executable
chmod +x *.sh

# Fix PID directory permissions
chmod 755 pids/
```

## 🔧 Platform Compatibility

- **macOS**: Full support with Terminal.app integration
- **Linux**: Partial support (manual terminal management)
- **Windows**: WSL/Git Bash (manual terminal management)

## 📦 Installation

```bash
# Clone the repository
git clone https://github.com/hdbernd/LGM_Spring_Boot_Manager.git
cd LGM_Spring_Boot_Manager

# Make scripts executable
chmod +x *.sh

# Configure your service paths in folders.txt
# Start the interactive manager
./service_manager.sh
```

## 📄 License

This project is part of the LGM (Logistics Management) development environment.

## 🤝 Contributing

To add features or fix issues:
1. Modify the appropriate script files
2. Test with your service configuration
3. Update this README if needed

---

**Happy developing with your Spring Boot microservices! 🚀**