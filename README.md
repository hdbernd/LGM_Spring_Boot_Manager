# LGM Spring Boot Service Manager

A comprehensive bash-based tool for managing multiple Spring Boot microservices with an interactive terminal UI. This tool provides unified management for development workflows including git operations, Maven builds, and service lifecycle management with **scenario-based service organization**.

**🔗 Repository**: https://github.com/hdbernd/LGM_Spring_Boot_Manager

> **Latest Update**: Complete build/run separation with organized scenario management. Separate configurations for build operations and flexible run scenarios (all, core, integration_and_warehouse) for different development contexts.

## 🚀 Features

### 🎯 Scenario-Based Service Management
- **Organized run scenarios** - Choose from predefined service combinations:
  - **All** - Complete LGM microservices ecosystem (8 services)
  - **Core** - Essential services for basic development (4 services)
  - **Integration & Warehouse** - Warehouse operations and integration testing (7 services)
- **Flexible scenario selection** - Switch between scenarios as needed
- **Custom scenarios** - Create your own service combinations

### 🔨 Separated Build & Run Operations
- **Build configuration** (`build_folders.txt`) - Services for git pull and Maven operations
- **Run scenarios** (`runs/*/services.txt`) - Service combinations for different contexts
- **Independent management** - Build all services while running only specific scenarios

### 🚀 Service Operations
- **Start/Stop/Restart** services in selected scenario with **separate terminal windows**
- **Real-time status monitoring** with Maven process detection and PID tracking
- **Proper network reachability** - each service runs in its own terminal session
- **Graceful shutdown** with Maven process detection and force-kill fallback

### 🔧 Build Operations
- **Git pull** for all repositories from build configuration
- **Maven clean install** for all projects from build configuration
- **Combined pull & build** workflow (equivalent to original `pull_and_build.sh`)
- **Progress tracking** with success/failure counters

### 📊 Monitoring & Logging
- **Scenario-aware status dashboard** with visual indicators
- **Log file management** and viewing
- **Individual service monitoring** within selected scenario
- **Build output tracking**

### 🎨 Interactive UI
- **Colorful terminal interface** with organized menus
- **Scenario selection interface** with service counts
- **Individual service management** with dedicated submenus
- **Real-time status updates** with scenario context
- **Error handling** with user-friendly messages

## 📁 Project Structure

```
LGM_Spring_Boot_Manager/
├── build_folders.txt.example          # Template for build configuration
├── run_all.txt.example                # All services scenario template
├── run_core.txt.example               # Core services scenario template
├── run_integration.txt.example        # Integration scenario template
├── service_manager.sh                 # Interactive terminal UI (main tool)
├── start_services.sh                  # Batch start script
├── stop_services.sh                   # Batch stop script
├── pull_and_build.sh                  # Original git pull & build script
├── pids/                              # Auto-generated PID and log directory
│   ├── *.pid                         # Process ID files
│   ├── *.log                         # Service log files
│   └── run_*.sh                      # Auto-generated startup scripts
├── .gitignore                         # Git ignore configuration
└── README.md                          # This file

# User-created files (not in git):
├── build_folders.txt                  # Your build service paths
└── run_*.txt                          # Your run scenario configurations
```

## 🛠 Setup

### Prerequisites
- **Bash** (macOS/Linux)
- **Git** installed and configured
- **Maven** (`mvn`) available in PATH
- **Java** environment configured for Spring Boot

### Configuration

1. **Clone the repository**:
   ```bash
   git clone https://github.com/hdbernd/LGM_Spring_Boot_Manager.git
   cd LGM_Spring_Boot_Manager
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Configure build services** (create `build_folders.txt`):
   ```bash
   cp build_folders.txt.example build_folders.txt
   # Edit build_folders.txt with your service paths for git/maven operations
   ```

4. **Configure run scenarios** (create run scenario files):
   ```bash
   # For all services scenario
   cp run_all.txt.example run_all.txt
   
   # For core services scenario  
   cp run_core.txt.example run_core.txt
   
   # For integration scenario
   cp run_integration.txt.example run_integration.txt
   
   # Edit each run_*.txt file with your local service paths
   ```

5. **Start the service manager**:
   ```bash
   ./service_manager.sh
   ```

## 🎮 Usage

### Interactive Service Manager (Recommended)

Start the main interactive UI:
```bash
./service_manager.sh
```

**Main Menu Options:**

🎯 **Scenario Management:**
- `1` - Select run scenario

🚀 **Service Operations:** (operates on selected scenario)
- `2` - Start all services
- `3` - Stop all services  
- `4` - Restart all services
- `5` - Manage individual services

🔨 **Build Operations:** (operates on build_folders.txt)
- `6` - Git pull all services
- `7` - Clean install all services
- `8` - Pull and build all services

📊 **Monitoring:**
- `9` - View logs
- `10` - Refresh status
- `11` - Exit

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

### Build Configuration (`build_folders.txt`)

```bash
# Build services - used for git pull and Maven clean install operations
# Comments start with #
# Blank lines are ignored

# Absolute paths to Spring Boot service directories
/Users/username/Documents/LGM_GIT/master-data-service
/Users/username/Documents/LGM_GIT/configuration-service
/Users/username/Documents/LGM_GIT/freight-tendering-service
# ... all services for build operations

# Tilde expansion is supported
~/Documents/LGM_GIT/stock-service
```

### Run Scenario Configuration (`run_*.txt`)

Each scenario file contains service paths for that specific scenario:

```bash
# Core scenario example (run_core.txt)
# Essential services only for lightweight development

/path/to/your/core-service-1
/path/to/your/core-service-2
/path/to/your/core-service-3
/path/to/your/core-service-4
```

### Requirements per Service Directory

Each service directory should contain:
- **`.git/`** - For git pull operations (build config only)
- **`pom.xml`** - For Maven build operations and running
- **Spring Boot Maven plugin** configured for `spring-boot:run`

### Scenario Organization

- **All** (`run_all.txt`) - Complete ecosystem for full system testing
- **Core** (`run_core.txt`) - Essential services for basic development
- **Integration** (`run_integration.txt`) - Integration testing and specialized workflows
- **Custom scenarios** - Create additional `run_*.txt` files as needed

## 🚦 Workflow Examples

### Complete Development Workflow
1. **Build all services**: Option `8` (Pull and build all) - Updates and builds all services
2. **Select scenario**: Option `1` (Select run scenario) - Choose "core" for lightweight development
3. **Start scenario services**: Option `2` (Start all services) - Starts only core services
4. **Monitor logs**: Option `9` (View logs)

### Quick Scenario Switch
1. **Select new scenario**: Option `1` - Switch from "core" to "all" 
2. **Start additional services**: Option `2` - Starts all services in new scenario
3. **Monitor status**: Option `10` (Refresh status)

### Individual Service Management
1. **Select scenario**: Option `1` - Choose target scenario
2. **Individual management**: Option `5` - Manage specific services in scenario
3. **Select specific service**
4. **Stop/restart/debug individual service**
5. **View service logs**: Option `7`

### Integration Testing Workflow  
1. **Select scenario**: Option `1` - Choose "integration_and_warehouse"
2. **Start scenario**: Option `2` - Starts warehouse and integration services
3. **Run integration tests** (external)
4. **Monitor logs**: Option `9` - Check service interactions

### Build vs Run Separation
- **Build operations** (options 6-8) always use `build_folders.txt` 
- **Service operations** (options 2-5) use selected run scenario
- **Example**: Build all 8 services, but run only 4 core services for development

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

## 📦 Quick Installation

```bash
# Clone the repository
git clone https://github.com/hdbernd/LGM_Spring_Boot_Manager.git
cd LGM_Spring_Boot_Manager

# Make scripts executable
chmod +x *.sh

# Configure build services
cp build_folders.txt.example build_folders.txt
# Edit build_folders.txt with your service paths

# Configure run scenarios (choose one or more)
cp run_core.txt.example run_core.txt
# Edit run_core.txt with your service paths

# Start the interactive manager
./service_manager.sh

# Select run scenario and start managing services!
```

## 🎯 Scenario Templates

The tool includes three pre-configured scenario templates:

### All Services (`run_all.txt`)
Complete microservices ecosystem for full system testing:
- Include all your services for comprehensive testing
- Use when you need the complete system running
- Best for integration testing and full workflow validation

### Core Services (`run_core.txt`)
Essential services for basic development and testing:
- Include only the essential services needed for basic functionality
- Use for lightweight development when you don't need all services
- Faster startup and less resource consumption

### Integration Services (`run_integration.txt`)
Integration testing and specialized workflows:
- Include services needed for integration testing
- Focus on services that interact with external systems
- Use for testing integration points and complex workflows

## 📄 License

This project is part of the LGM (Logistics Management) development environment.

## 🤝 Contributing

To add features or fix issues:
1. Modify the appropriate script files
2. Test with your service configuration
3. Update this README if needed

---

**Happy developing with your Spring Boot microservices! 🚀**