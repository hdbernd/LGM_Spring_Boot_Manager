# LGM Spring Boot Service Manager - Claude Code Project

## Project Overview
This is the **LGM Spring Boot Service Manager** - a comprehensive bash-based tool for managing multiple Spring Boot microservices with an interactive terminal UI and scenario-based service organization.

## Key Features
- **Scenario-based management**: All, Core, Integration & Warehouse service combinations
- **Interactive terminal UI**: Colorful menu system with real-time status monitoring
- **Service lifecycle management**: Start/stop/restart services in separate terminal windows
- **Build operations**: Git pull, Maven clean install, combined workflows
- **Default configuration**: Automatic loading of preferred settings
- **Logging & monitoring**: Startup statistics, service logs, status indicators

## Project Structure
- `service_manager.sh` - Main interactive terminal UI
- `start_services.sh` / `stop_services.sh` - Batch service management
- `pull_and_build.sh` - Git pull and Maven build operations
- `run_*.txt` - Service scenario configurations
- `build_folders.txt` - Build configuration paths
- `pids/` - Runtime data (PIDs, logs, startup scripts)

## Configuration Files
- `.default_config` - Default run scenario and build mode settings
- `run_all.txt` - All services scenario (8 services)
- `run_core.txt` - Core services scenario (4 services)
- `run_integration_*.txt` - Various integration scenarios
- `build_folders.txt` - Services for build operations

## Current Status
- Project is fully functional with comprehensive documentation
- Default configuration system is implemented
- Multiple service scenarios are configured
- Build vs run separation is working
- Logging and monitoring features are active
- **NEW**: Command-line parameter support for run profiles
- **NEW**: Permanent default profile functionality

## Development Notes
This project manages LGM (Logistics Management) microservices including:
- master-data-service
- configuration-service
- freight-tendering-service
- stock-service
- wm-internal-process-service
- outbound-process-service
- transport-execution-service
- transport-planning-service

The tool provides unified management for development workflows with proper process isolation and monitoring capabilities.

## New Features Added

### Command-Line Parameter Support
The service manager now supports command-line parameters for easy automation and quick profile switching:

**Usage:**
```bash
./service_manager.sh [OPTIONS] [PROFILE]
```

**Options:**
- `-h, --help` - Show help message
- `-s, --set-default PROFILE` - Set PROFILE as permanent default
- `-c, --clear-default` - Clear permanent default profile
- `-l, --list-profiles` - List available run profiles
- `-d, --show-default` - Show current default configuration

**Examples:**
```bash
./service_manager.sh                      # Interactive mode
./service_manager.sh core                 # Start with core profile
./service_manager.sh --set-default core   # Set core as permanent default
./service_manager.sh --list-profiles      # Show available profiles
```

### Permanent Default Profile
The tool now supports setting a permanent default profile that will be automatically loaded on startup:

- Use `--set-default PROFILE` to set a permanent default
- Use `--clear-default` to remove the permanent default
- Use `--show-default` to view current default configuration
- Default profiles are stored in `.default_config` file

**Priority Order:**
1. Profile specified on command line
2. Permanent default profile (if set)
3. Interactive mode selection

### Enhanced Interactive Mode
The interactive mode now provides better default configuration management:

- **Default configuration display**: Main menu shows current default profile and build mode
- **Enhanced default management**: Option 3 now includes:
  - Set current configuration as default
  - Set specific profile as default (without needing to select it first)
  - Clear default configuration
  - View default configuration file
- **Session vs. defaults**: Shows both current session configuration and saved defaults
- **Automatic loading**: Defaults are automatically applied when starting interactively

**Interactive Features:**
- Displays default configuration status in main menu
- Shows difference between current session and saved defaults
- Allows setting any available profile as default directly
- Provides clear visual feedback for default configuration changes