# LGM Spring Boot Service Manager

A comprehensive bash-based tool for managing multiple Spring Boot microservices with an interactive terminal UI. This tool provides unified management for development workflows including git operations, Maven builds, and service lifecycle management with **scenario-based service organization**.

**🔗 Repository**: https://github.com/hdbernd/LGM_Spring_Boot_Manager

> **Latest Update**: Added command-line parameter support and enhanced interactive default configuration management. Start with specific profiles directly from command line, set permanent defaults, and manage configurations seamlessly in both interactive and command-line modes.

## 🚀 Features

### 🎯 Scenario-Based Service Management
- **Organized run scenarios** - Choose from predefined service combinations:
  - **All** - Complete LGM microservices ecosystem (8 services)
  - **Core** - Essential services for basic development (4 services)
  - **Integration & Warehouse** - Warehouse operations and integration testing (7 services)
- **Flexible scenario selection** - Switch between scenarios as needed
- **Custom scenarios** - Create your own service combinations

### 🔨 Flexible Build & Run Operations
- **Build configuration modes** - Choose between `build_folders.txt` or run scenarios for build operations
- **Traditional mode** - Use dedicated `build_folders.txt` for git pull and Maven operations
- **Scenario-based mode** - Use selected run scenario for build operations
- **Independent management** - Build all services while running only specific scenarios
- **Dynamic switching** - Change build configuration mode at runtime

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
- **Startup time tracking** with automatic timing statistics
- **Log file management** and viewing
- **Individual service monitoring** within selected scenario
- **Build output tracking**
- **Startup statistics dashboard** with averages and history

### 🎨 Interactive UI
- **Colorful terminal interface** with organized menus
- **Scenario selection interface** with service counts
- **Individual service management** with dedicated submenus
- **Real-time status updates** with scenario context
- **Error handling** with user-friendly messages
- **Default configuration display** with status visibility
- **Enhanced default management** with direct profile selection

### 📋 Command-Line Interface
- **Direct profile startup** - Start with specific profile: `./service_manager.sh core`
- **Permanent default management** - Set/clear default profiles from command line
- **Profile listing** - View available profiles: `./service_manager.sh --list-profiles`
- **Configuration display** - Show current defaults: `./service_manager.sh --show-default`
- **Help system** - Built-in usage information: `./service_manager.sh --help`
- **Priority system** - Command-line profile → Permanent default → Interactive selection

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
│   ├── startup_stats.log             # Startup time statistics
│   └── run_*.sh                      # Auto-generated startup scripts
├── .gitignore                         # Git ignore configuration
└── README.md                          # This file

# User-created files (not in git):
├── build_folders.txt                  # Your build service paths
└── run_*.txt                          # Your run scenario configurations
```

## 🛠 Setup

### Prerequisites
- **Bash** (macOS/Linux) or **Git Bash** (Windows)
- **Git** installed and configured
- **Maven** (`mvn`) available in PATH
- **Java** environment configured for Spring Boot

#### Windows Users
For Windows users, you have several options:
- **Git Bash** (Recommended): Install [Git for Windows](https://gitforwindows.org/) which includes Git Bash
- **WSL2**: Use Windows Subsystem for Linux with Ubuntu
- **Docker**: Run services in Linux containers

**Note**: Windows native Command Prompt and PowerShell are not currently supported due to terminal management requirements.

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

### Command-Line Options

```bash
Usage: ./service_manager.sh [OPTIONS] [PROFILE]

Options:
  -h, --help              Show help message
  -s, --set-default PROFILE  Set PROFILE as permanent default
  -c, --clear-default     Clear permanent default profile
  -l, --list-profiles     List available run profiles
  -d, --show-default      Show current default configuration

Profile:
  Name of the run profile to use (e.g., core, all, integration)
  Available profiles are determined by run_*.txt files

Examples:
  ./service_manager.sh                      # Interactive mode
  ./service_manager.sh core                 # Start with core profile
  ./service_manager.sh --set-default core   # Set core as permanent default
  ./service_manager.sh --list-profiles      # Show available profiles
```

### Command-Line Usage

The service manager supports both interactive and command-line modes:

```bash
# Interactive mode (default)
./service_manager.sh

# Start with specific profile
./service_manager.sh core
./service_manager.sh integration_minimum

# Set permanent default profile
./service_manager.sh --set-default core

# Clear permanent default
./service_manager.sh --clear-default

# List available profiles
./service_manager.sh --list-profiles

# Show current default configuration
./service_manager.sh --show-default

# Show help
./service_manager.sh --help
```

### Interactive Service Manager

Start the main interactive UI:
```bash
./service_manager.sh
```

**Main Menu Options:**

🎯 **Scenario Management:**
- `1` - Select run scenario
- `2` - Select build configuration
- `3` - Manage default configuration

🚀 **Service Operations:** (operates on selected scenario)
- `4` - Start all services
- `5` - Stop all services  
- `6` - Restart all services
- `7` - Manage individual services

🔨 **Build Operations:** (operates on selected build configuration)
- `8` - Git pull all services
- `9` - Clean install all services
- `10` - Pull and build all services

📊 **Monitoring:**
- `11` - View logs
- `12` - View startup statistics
- `13` - Refresh status
- `14` - Exit

### Default Configuration

The service manager supports comprehensive default configuration management:

#### Command-Line Default Management
```bash
# Set permanent default profile
./service_manager.sh --set-default core

# Clear permanent default
./service_manager.sh --clear-default

# View current defaults
./service_manager.sh --show-default
```

#### Interactive Default Management
- **Main menu display**: Shows current default configuration at the top
- **Option 3**: Enhanced default configuration management
  - **Set current as default**: Save current scenario and build mode as defaults
  - **Set specific profile as default**: Choose any profile without selecting it first
  - **Clear defaults**: Remove default configuration file
  - **View configuration**: Display current default settings
- **Session vs. defaults**: Shows both current session and saved defaults

#### Default Configuration Features
- **Auto-loading**: Defaults are automatically applied when starting
- **Priority system**: Command-line profile → Permanent default → Interactive selection
- **Visual feedback**: Clear indicators for default configuration status
- **Location**: `.default_config` (hidden file in project directory)
- **Format**: Simple key=value pairs

Example `.default_config`:
```
DEFAULT_RUN_SCENARIO=core
DEFAULT_BUILD_MODE=run_scenario
```

### Individual Service Management

Select option `7` from the main menu to access individual service controls:

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

## 📝 Logging & Statistics

All service logs and startup statistics are automatically managed:

### Service Logs
- **Location**: `pids/` directory
- **Format**: `{service-name}.log`
- **Content**: Complete Spring Boot startup and runtime logs with timing information
- **Viewing**: Use option `9` in the UI or check files directly

### Startup Statistics
- **Automatic timing**: Each service startup is measured and logged
- **Statistics file**: `pids/startup_stats.log` with timestamped startup times
- **Dashboard**: Option `10` shows recent startup times and averages
- **Visual feedback**: Clear startup completion messages with timing in terminal

Example files:
```
pids/master-data-service.log      # Service logs with startup timing
pids/configuration-service.log    # Service logs with startup timing
pids/startup_stats.log           # Aggregated startup statistics
```

Example startup statistics display:
```
📊 Startup Statistics:

Recent startup times:
  2025-07-16 14:23:45: master-data-service started in 12s
  2025-07-16 14:24:02: configuration-service started in 8s
  2025-07-16 14:24:15: stock-service started in 15s

📈 Summary:
  Total service starts: 15
  Average startup time: 11.3s
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
1. **Select run scenario**: Option `1` (Select run scenario) - Choose "core" for lightweight development
2. **Select build configuration**: Option `2` (Select build configuration) - Choose "run scenario" to build only core services
3. **Save as default**: Option `3` (Manage default configuration) - Save current settings as defaults for next startup
4. **Build scenario services**: Option `10` (Pull and build all) - Updates and builds only core services
5. **Start scenario services**: Option `4` (Start all services) - Starts core services
6. **Monitor logs**: Option `11` (View logs)

### Quick Scenario Switch
1. **Select new scenario**: Option `1` - Switch from "core" to "all" 
2. **Start additional services**: Option `4` - Starts all services in new scenario
3. **Monitor status**: Option `13` (Refresh status)

### Individual Service Management
1. **Select scenario**: Option `1` - Choose target scenario
2. **Individual management**: Option `7` - Manage specific services in scenario
3. **Select specific service**
4. **Stop/restart/debug individual service**
5. **View service logs**: Option `7`

### Integration Testing Workflow  
1. **Select scenario**: Option `1` - Choose "integration_and_warehouse"
2. **Start scenario**: Option `4` - Starts warehouse and integration services
3. **Run integration tests** (external)
4. **Monitor logs**: Option `11` - Check service interactions

### Build Configuration Modes

The tool now supports two modes for build operations:

#### Traditional Mode (build_folders.txt)
- **Git pull, clean install, pull & build** operations use `build_folders.txt`
- **Independent of run scenarios** - build all services regardless of selected scenario
- **Best for**: Full development environment where you want to build all services

#### Scenario-Based Mode (run scenario)
- **Git pull, clean install, pull & build** operations use the selected run scenario
- **Consistent with service operations** - build only the services you're running
- **Best for**: Focused development where you only need specific services

#### Switching Between Modes
- Use menu option `2` to select build configuration mode
- Changes affect all build operations (git pull, clean install, pull & build)
- Current mode is displayed in the main menu
- Switch at any time during your session

### Build vs Run Separation
- **Build operations** (options 7-9) use selected build configuration mode
- **Service operations** (options 3-6) always use selected run scenario
- **Example**: Build only core services (scenario mode) and run only those same services

### New Build Configuration Workflow Examples

#### Scenario-Based Build Mode
1. **Select run scenario**: Option `1` - Choose "core" 
2. **Select build configuration**: Option `2` - Choose "run scenario"
3. **Build scenario services**: Option `10` - Builds only core services
4. **Start scenario services**: Option `4` - Starts core services
5. **Result**: Complete consistency - build and run the same services

#### Traditional Build Mode
1. **Select run scenario**: Option `1` - Choose "core"
2. **Select build configuration**: Option `2` - Choose "build_folders.txt"
3. **Build all services**: Option `10` - Builds all services in build_folders.txt
4. **Start scenario services**: Option `4` - Starts only core services
5. **Result**: Build all, run subset - traditional workflow

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

### Windows-Specific Issues
- **Git Bash Path Issues**: Ensure paths use forward slashes (`/`) not backslashes (`\`)
- **Java/Maven not found**: Add Java and Maven to Windows PATH or use Git Bash profile
- **Terminal windows**: Services may not open in separate windows - use manual startup
- **Permission errors**: Run Git Bash as Administrator if needed
- **Line ending issues**: Ensure scripts have Unix line endings (LF not CRLF)

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

### **macOS** ✅ **Full Support**
- Complete Terminal.app integration with separate windows for each service
- All features work seamlessly including service startup, monitoring, and management
- Automatic process detection and cleanup

### **Linux** ⚠️ **Partial Support**
- Falls back to `gnome-terminal` or `xterm` for service terminals
- Core functionality works but may require manual terminal management
- Git operations and build processes work normally
- Service monitoring and process management available

### **Windows** ⚠️ **Limited Support via Git Bash**
- **Git Bash** provides the best Windows experience
- All command-line features work (profiles, defaults, build operations)
- **Service terminal limitation**: Services run in the same Git Bash window
- Manual service startup recommended: `cd service-directory && mvn spring-boot:run`

#### Windows Setup with Git Bash
1. **Install Git for Windows**: Download from [gitforwindows.org](https://gitforwindows.org/)
2. **Open Git Bash**: Right-click in project folder → "Git Bash Here"
3. **Run the service manager**: `./service_manager.sh`
4. **Manual service startup**: For services, open separate Git Bash windows:
   ```bash
   cd /path/to/service-directory
   mvn spring-boot:run
   ```

#### Alternative Windows Options
- **WSL2**: Full Linux compatibility with Ubuntu/Debian
- **Docker Desktop**: Run services in Linux containers
- **PowerShell**: Limited support (command-line features only)

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