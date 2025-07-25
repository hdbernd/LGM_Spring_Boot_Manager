#!/bin/bash

# Spring Boot Service Manager - Interactive Terminal UI
# Manages Spring Boot services with a simple menu interface
# Usage: ./service_manager.sh [OPTIONS] [PROFILE]
# Examples:
#   ./service_manager.sh                    # Interactive mode
#   ./service_manager.sh core               # Start with core profile
#   ./service_manager.sh --set-default core # Set core as permanent default
#   ./service_manager.sh --help             # Show help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_FOLDERS_FILE="$SCRIPT_DIR/build_folders.txt"
PID_DIR="$SCRIPT_DIR/pids"
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/.default_config"

# Current run scenario (set by user selection)
CURRENT_RUN_SCENARIO=""
CURRENT_RUN_FILE=""

# Build configuration mode - either "build_folders" or "run_scenario"
BUILD_CONFIG_MODE="build_folders"

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Create PID directory if it doesn't exist
mkdir -p "$PID_DIR"

# Function to show usage information
show_usage() {
    echo "Spring Boot Service Manager - Interactive Terminal UI"
    echo ""
    echo "Usage: $0 [OPTIONS] [PROFILE]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -s, --set-default PROFILE  Set PROFILE as the permanent default"
    echo "  -c, --clear-default     Clear the permanent default profile"
    echo "  -l, --list-profiles     List available run profiles"
    echo "  -d, --show-default      Show current default configuration"
    echo ""
    echo "Profile:"
    echo "  Name of the run profile to use (e.g., core, all, integration)"
    echo "  Available profiles are determined by run_*.txt files"
    echo ""
    echo "Examples:"
    echo "  $0                      # Interactive mode"
    echo "  $0 core                 # Start with core profile"
    echo "  $0 --set-default core   # Set core as permanent default"
    echo "  $0 --list-profiles      # Show available profiles"
    echo ""
    echo "If no profile is specified, the script will:"
    echo "  1. Use the profile from --set-default if set"
    echo "  2. Use the default configuration if available"
    echo "  3. Start in interactive mode"
}

# Function to list available profiles
list_profiles() {
    echo "Available run profiles:"
    echo ""
    local scenarios=($(get_run_scenarios))
    if [[ ${#scenarios[@]} -eq 0 ]]; then
        echo "  No run profile files found"
        echo "  Please create run_*.txt files with service paths"
    else
        for scenario_file in "${scenarios[@]}"; do
            local scenario_name=$(basename "$scenario_file" .txt)
            local display_name=${scenario_name#run_}  # Remove 'run_' prefix
            if [[ -f "$scenario_file" ]]; then
                local service_count=$(grep -v "^[[:space:]]*#" "$scenario_file" | grep -v "^[[:space:]]*$" | wc -l | xargs)
                echo "  - $display_name ($service_count services)"
            else
                echo "  - $display_name (file not found)"
            fi
        done
    fi
}

# Function to show current default configuration
show_current_default() {
    echo "Current default configuration:"
    echo ""
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        local default_scenario=""
        local default_build_mode=""
        
        while IFS='=' read -r key value; do
            case $key in
                DEFAULT_RUN_SCENARIO)
                    default_scenario="$value"
                    ;;
                DEFAULT_BUILD_MODE)
                    default_build_mode="$value"
                    ;;
            esac
        done < "$DEFAULT_CONFIG_FILE"
        
        echo "  📋 Default run profile: ${default_scenario:-None}"
        echo "  🔨 Default build mode: ${default_build_mode:-None}"
    else
        echo "  No default configuration set"
    fi
}

# Function to set permanent default profile
set_permanent_default() {
    local profile="$1"
    local scenario_file="$SCRIPT_DIR/run_$profile.txt"
    
    if [[ ! -f "$scenario_file" ]]; then
        echo -e "${RED}❌ Profile '$profile' not found${NC}"
        echo -e "${YELLOW}Available profiles:${NC}"
        list_profiles
        exit 1
    fi
    
    # Determine current build mode or use default
    local build_mode="build_folders"
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            case $key in
                DEFAULT_BUILD_MODE)
                    build_mode="$value"
                    ;;
            esac
        done < "$DEFAULT_CONFIG_FILE"
    fi
    
    save_default_config "$profile" "$build_mode"
    echo -e "${GREEN}✅ '$profile' is now the permanent default profile${NC}"
}

# Function to clear permanent default
clear_permanent_default() {
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        rm -f "$DEFAULT_CONFIG_FILE"
        echo -e "${GREEN}✅ Permanent default configuration cleared${NC}"
    else
        echo -e "${YELLOW}No default configuration to clear${NC}"
    fi
}

# Function to load profile from command line
load_profile_from_cmdline() {
    local profile="$1"
    local scenario_file="$SCRIPT_DIR/run_$profile.txt"
    
    if [[ ! -f "$scenario_file" ]]; then
        echo -e "${RED}❌ Profile '$profile' not found${NC}"
        echo -e "${YELLOW}Available profiles:${NC}"
        list_profiles
        exit 1
    fi
    
    CURRENT_RUN_SCENARIO="$profile"
    CURRENT_RUN_FILE="$scenario_file"
    echo -e "${GREEN}📋 Using profile: $profile${NC}"
}

# Function to load default configuration
load_default_config() {
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        local default_scenario=""
        local default_build_mode=""
        
        # Read configuration file
        while IFS='=' read -r key value; do
            case $key in
                DEFAULT_RUN_SCENARIO)
                    default_scenario="$value"
                    ;;
                DEFAULT_BUILD_MODE)
                    default_build_mode="$value"
                    ;;
            esac
        done < "$DEFAULT_CONFIG_FILE"
        
        # Apply default run scenario if valid
        if [[ -n "$default_scenario" ]]; then
            local scenario_file="$SCRIPT_DIR/run_$default_scenario.txt"
            if [[ -f "$scenario_file" ]]; then
                CURRENT_RUN_SCENARIO="$default_scenario"
                CURRENT_RUN_FILE="$scenario_file"
                echo -e "${GREEN}📋 Loaded default run scenario: $default_scenario${NC}"
            else
                echo -e "${YELLOW}⚠️  Default scenario '$default_scenario' not found, file: $scenario_file${NC}"
            fi
        fi
        
        # Apply default build mode if valid
        if [[ -n "$default_build_mode" ]]; then
            if [[ "$default_build_mode" == "build_folders" || "$default_build_mode" == "run_scenario" ]]; then
                BUILD_CONFIG_MODE="$default_build_mode"
                echo -e "${GREEN}🔨 Loaded default build mode: $default_build_mode${NC}"
            else
                echo -e "${YELLOW}⚠️  Invalid default build mode: $default_build_mode${NC}"
            fi
        fi
    fi
}

# Function to save default configuration
save_default_config() {
    local run_scenario="$1"
    local build_mode="$2"
    
    cat > "$DEFAULT_CONFIG_FILE" << EOF
# Default configuration for Spring Boot Service Manager
# This file is automatically generated and loaded on startup

DEFAULT_RUN_SCENARIO=$run_scenario
DEFAULT_BUILD_MODE=$build_mode
EOF
    
    echo -e "${GREEN}✅ Default configuration saved${NC}"
    echo -e "${CYAN}   Run scenario: $run_scenario${NC}"
    echo -e "${CYAN}   Build mode: $build_mode${NC}"
}

# Function to clear screen and show header
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}              🚀 Spring Boot Service Manager              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Helper function to find Maven/Java processes for a service
find_service_processes() {
    local folder="$1"
    local service_name=$(basename "$folder")
    local found_pids=""
    
    # Pattern 1: Look for Maven processes with spring-boot:run in service directory
    found_pids=$(pgrep -f "mvn.*spring-boot:run" | while read pid; do
        local proc_cwd=$(lsof -p "$pid" 2>/dev/null | grep " cwd " | awk '{print $NF}')
        if [[ "$proc_cwd" == "$folder" || "$proc_cwd" == "$folder"* ]]; then
            echo "$pid"
        fi
    done)
    
    # Pattern 2: If no Maven process found, try looking for java processes with Spring Boot characteristics
    if [[ -z "$found_pids" ]]; then
        found_pids=$(pgrep -f "java.*spring-boot" | while read pid; do
            local proc_cwd=$(lsof -p "$pid" 2>/dev/null | grep " cwd " | awk '{print $NF}')
            if [[ "$proc_cwd" == "$folder" || "$proc_cwd" == "$folder"* ]]; then
                echo "$pid"
            fi
        done)
    fi
    
    # Pattern 3: Check if service name appears in process command line  
    if [[ -z "$found_pids" ]]; then
        found_pids=$(pgrep -f "$service_name" | while read pid; do
            # Verify it's a Maven or Java process
            if ps -p "$pid" -o command= 2>/dev/null | grep -q -E "(mvn|java).*(spring-boot|SpringApplication)"; then
                echo "$pid"
            fi
        done)
    fi
    
    echo "$found_pids"
}

# Function to get service status with optional thorough checking
get_service_status() {
    local folder="$1"
    local thorough_check="${2:-false}"  # Default to quick check
    local service_name=$(basename "$folder")
    local pid_file="$PID_DIR/$service_name.pid"
    
    # Quick check: Only check PID file first
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            # Check if this is still a relevant process (Maven/Java)
            if ps -p "$pid" -o command= 2>/dev/null | grep -q -E "(mvn|java).*(spring-boot|SpringApplication)"; then
                echo -e "${GREEN}●${NC} Running (PID: $pid)"
                return 0
            else
                echo -e "${YELLOW}●${NC} Terminal open (PID: $pid)"
                return 0
            fi
        else
            # PID file exists but process is dead - clean it up
            rm -f "$pid_file"
        fi
    fi
    
    # Thorough check: Use expensive process scanning only if requested
    if [[ "$thorough_check" == "true" ]]; then
        local mvn_pids=$(find_service_processes "$folder")
        
        if [[ -n "$mvn_pids" ]]; then
            local mvn_pid=$(echo "$mvn_pids" | head -1)
            # Update PID file with actual Maven/Java PID
            echo "$mvn_pid" > "$pid_file"
            echo -e "${GREEN}●${NC} Running (PID: $mvn_pid)"
            return 0
        fi
    fi
    
    echo -e "${RED}●${NC} Stopped"
}

# Function to get available run scenarios
get_run_scenarios() {
    find "$SCRIPT_DIR" -name "run_*.txt" -type f | sort
}

# Function to manage default configuration
manage_default_config() {
    while true; do
        show_header
        echo -e "${WHITE}⚙️  Manage Default Configuration:${NC}"
        echo ""
        
        # Show current defaults
        if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
            echo -e "${CYAN}Current defaults:${NC}"
            local current_run_scenario=""
            local current_build_mode=""
            
            while IFS='=' read -r key value; do
                case $key in
                    DEFAULT_RUN_SCENARIO)
                        current_run_scenario="$value"
                        ;;
                    DEFAULT_BUILD_MODE)
                        current_build_mode="$value"
                        ;;
                esac
            done < "$DEFAULT_CONFIG_FILE"
            
            echo "  📋 Run scenario: ${current_run_scenario:-None}"
            echo "  🔨 Build mode: ${current_build_mode:-None}"
        else
            echo -e "${YELLOW}No default configuration set${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Current session:${NC}"
        echo "  📋 Run scenario: ${CURRENT_RUN_SCENARIO:-None}"
        echo "  🔨 Build mode: ${BUILD_CONFIG_MODE:-None}"
        echo ""
        echo "1) Set current configuration as default"
        echo "2) Set specific profile as default"
        echo "3) Clear default configuration"
        echo "4) View default configuration file"
        echo "0) Back to main menu"
        echo ""
        echo -n "Choose an option [0-4]: "
        read -r choice
        
        case $choice in
            0)
                return
                ;;
            1)
                if [[ -z "$CURRENT_RUN_SCENARIO" ]]; then
                    echo ""
                    echo -e "${RED}❌ No run scenario selected${NC}"
                    echo -e "${YELLOW}Please select a run scenario first${NC}"
                    echo -n "Press Enter to continue..."
                    read -r
                    continue
                fi
                
                save_default_config "$CURRENT_RUN_SCENARIO" "$BUILD_CONFIG_MODE"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                # Set specific profile as default
                echo ""
                echo -e "${CYAN}Available profiles:${NC}"
                local scenarios=($(get_run_scenarios))
                if [[ ${#scenarios[@]} -eq 0 ]]; then
                    echo -e "${RED}❌ No run scenario files found${NC}"
                    echo -n "Press Enter to continue..."
                    read -r
                    continue
                fi
                
                local i=1
                for scenario_file in "${scenarios[@]}"; do
                    local scenario_name=$(basename "$scenario_file" .txt)
                    local display_name=${scenario_name#run_}  # Remove 'run_' prefix
                    if [[ -f "$scenario_file" ]]; then
                        local service_count=$(grep -v "^[[:space:]]*#" "$scenario_file" | grep -v "^[[:space:]]*$" | wc -l | xargs)
                        echo "  $i) ${display_name} ($service_count services)"
                    fi
                    ((i++))
                done
                
                echo ""
                echo -n "Choose a profile to set as default [1-$((i-1))] or 0 to cancel: "
                read -r profile_choice
                
                if [[ "$profile_choice" == "0" ]]; then
                    continue
                elif [[ "$profile_choice" =~ ^[0-9]+$ ]] && [[ $profile_choice -ge 1 ]] && [[ $profile_choice -lt $i ]]; then
                    local selected_file="${scenarios[$((profile_choice-1))]}"
                    local scenario_name=$(basename "$selected_file" .txt)
                    local display_name=${scenario_name#run_}
                    
                    if [[ -f "$selected_file" ]]; then
                        save_default_config "$display_name" "$BUILD_CONFIG_MODE"
                        echo ""
                        echo -e "${GREEN}✅ '$display_name' is now the default profile${NC}"
                    else
                        echo ""
                        echo -e "${RED}❌ Profile file not found${NC}"
                    fi
                else
                    echo ""
                    echo -e "${RED}Invalid selection${NC}"
                fi
                echo -n "Press Enter to continue..."
                read -r
                ;;
            3)
                if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
                    rm -f "$DEFAULT_CONFIG_FILE"
                    echo ""
                    echo -e "${GREEN}✅ Default configuration cleared${NC}"
                else
                    echo ""
                    echo -e "${YELLOW}No default configuration to clear${NC}"
                fi
                echo -n "Press Enter to continue..."
                read -r
                ;;
            4)
                echo ""
                if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
                    echo -e "${CYAN}📄 Default configuration file contents:${NC}"
                    echo ""
                    cat "$DEFAULT_CONFIG_FILE"
                else
                    echo -e "${YELLOW}No default configuration file exists${NC}"
                fi
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to select build configuration mode
select_build_config() {
    while true; do
        show_header
        echo -e "${WHITE}🔨 Select Build Configuration Mode:${NC}"
        echo ""
        echo "Build operations (git pull, clean install, pull & build) can use:"
        echo ""
        echo "1) Build folders configuration (build_folders.txt)"
        echo "   - Uses dedicated build configuration file"
        echo "   - Independent of run scenarios"
        echo "   - Traditional mode"
        echo ""
        echo "2) Current run scenario"
        if [[ -n "$CURRENT_RUN_SCENARIO" ]]; then
            echo "   - Uses services from: $CURRENT_RUN_SCENARIO scenario"
        else
            echo "   - Uses services from selected run scenario"
            echo "   - ⚠️  You must select a run scenario first"
        fi
        echo ""
        echo "0) Back to main menu"
        echo ""
        echo -e "${CYAN}Current build mode: ${BUILD_CONFIG_MODE}${NC}"
        echo ""
        echo -n "Choose build configuration [0-2]: "
        read -r choice
        
        case $choice in
            0)
                return
                ;;
            1)
                BUILD_CONFIG_MODE="build_folders"
                echo ""
                echo -e "${GREEN}✅ Build configuration set to: build_folders.txt${NC}"
                echo -n "Press Enter to continue..."
                read -r
                return
                ;;
            2)
                if [[ -z "$CURRENT_RUN_FILE" ]]; then
                    echo ""
                    echo -e "${RED}❌ No run scenario selected${NC}"
                    echo -e "${YELLOW}Please select a run scenario first${NC}"
                    echo -n "Press Enter to continue..."
                    read -r
                    continue
                fi
                BUILD_CONFIG_MODE="run_scenario"
                echo ""
                echo -e "${GREEN}✅ Build configuration set to: $CURRENT_RUN_SCENARIO scenario${NC}"
                echo -n "Press Enter to continue..."
                read -r
                return
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to select run scenario
select_run_scenario() {
    local scenarios=($(get_run_scenarios))
    
    if [[ ${#scenarios[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No run scenario files found${NC}"
        echo -e "${YELLOW}Please create run_*.txt files with service paths${NC}"
        return 1
    fi
    
    while true; do
        show_header
        echo -e "${WHITE}🎯 Select Run Scenario:${NC}"
        echo ""
        
        local i=1
        for scenario_file in "${scenarios[@]}"; do
            local scenario_name=$(basename "$scenario_file" .txt)
            local display_name=${scenario_name#run_}  # Remove 'run_' prefix
            
            if [[ -f "$scenario_file" ]]; then
                local service_count=$(grep -v "^[[:space:]]*#" "$scenario_file" | grep -v "^[[:space:]]*$" | wc -l | xargs)
                echo "  $i) ${display_name} ($service_count services)"
            else
                echo "  $i) ${display_name} (file not found)"
            fi
            ((i++))
        done
        
        echo ""
        echo "  0) Back to main menu"
        echo ""
        echo -n "Choose a scenario [0-$((i-1))]: "
        read -r choice
        
        if [[ "$choice" == "0" ]]; then
            return 1
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -lt $i ]]; then
            local selected_file="${scenarios[$((choice-1))]}"
            local scenario_name=$(basename "$selected_file" .txt)
            local display_name=${scenario_name#run_}
            
            if [[ ! -f "$selected_file" ]]; then
                echo ""
                echo -e "${RED}❌ Scenario file not found: $selected_file${NC}"
                echo -n "Press Enter to continue..."
                read -r
                continue
            fi
            
            CURRENT_RUN_SCENARIO="$display_name"
            CURRENT_RUN_FILE="$selected_file"
            echo ""
            echo -e "${GREEN}✅ Selected scenario: $display_name${NC}"
            echo -n "Press Enter to continue..."
            read -r
            return 0
        else
            echo ""
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 1
        fi
    done
}

# Function to show service status for current scenario
show_status() {
    local thorough_check="${1:-false}"  # Default to quick check
    
    if [[ -z "$CURRENT_RUN_SCENARIO" ]]; then
        echo -e "${WHITE}📊 Service Status:${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  No run scenario selected${NC}"
        echo -e "${CYAN}Use 'Select Run Scenario' to choose services to manage${NC}"
        echo ""
        return
    fi
    
    echo -e "${WHITE}📊 Service Status - Scenario: ${CYAN}$CURRENT_RUN_SCENARIO${NC}"
    if [[ "$thorough_check" == "true" ]]; then
        echo -e "${YELLOW}🔍 Performing thorough process scan...${NC}"
    fi
    echo ""
    
    local running_count=0
    local total_count=0
    local service_count=0
    
    # Count total services first for progress indication
    local total_services=$(grep -v '^[[:space:]]*#' "$CURRENT_RUN_FILE" | grep -c '^[[:space:]]*[^[:space:]]')
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            local service_name=$(basename "$folder")
            ((service_count++))
            
            # Show progress indicator for thorough checks
            if [[ "$thorough_check" == "true" ]]; then
                printf "\r${BLUE}🔄 Checking services... (%d/%d) %s${NC}" "$service_count" "$total_services" "$service_name"
                echo -en "\033[K"  # Clear to end of line
            fi
            
            local status=$(get_service_status "$folder" "$thorough_check")
            
            # Clear progress line and show result
            if [[ "$thorough_check" == "true" ]]; then
                printf "\r\033[K"  # Clear the progress line
            fi
            
            printf "  %-35s %s\n" "$service_name" "$status"
            
            if [[ "$status" == *"Running"* ]]; then
                ((running_count++))
            fi
            ((total_count++))
        fi
    done < "$CURRENT_RUN_FILE"
    
    echo ""
    echo -e "${CYAN}Summary: ${running_count}/${total_count} services running in $CURRENT_RUN_SCENARIO scenario${NC}"
    if [[ "$thorough_check" == "true" && "$running_count" -eq 0 ]]; then
        echo -e "${YELLOW}💡 Tip: Use 'Start all services' if you want to start the scenario services${NC}"
    fi
    echo ""
}

# Function to start a single service using JAR (faster startup)
start_service_jar() {
    local folder="$1"
    local service_name=$(basename "$folder")
    
    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}❌ Error: Directory $folder does not exist${NC}"
        return 1
    fi
    
    # Find the executable JAR
    local jar_file=$(find "$folder/target" -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" 2>/dev/null | head -1)
    if [[ ! -f "$jar_file" ]]; then
        echo -e "${RED}❌ Error: No executable JAR found in $folder/target${NC}"
        echo -e "${YELLOW}💡 Tip: Run 'Build JARs for all services' first${NC}"
        return 1
    fi
    
    # Check if already running
    local pid_file="$PID_DIR/$service_name.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  $service_name is already running (PID: $pid)${NC}"
            return 0
        fi
    fi
    
    echo -e "${BLUE}🚀 Starting $service_name from JAR in new terminal (FAST MODE)...${NC}"
    
    # Create a script to run in the new terminal
    local run_script="$PID_DIR/run_$service_name.sh"
    cat > "$run_script" << EOF
#!/bin/bash

# Service configuration
SERVICE_NAME="$service_name"
LOG_FILE="$PID_DIR/$service_name.log"
STATS_FILE="$PID_DIR/startup_stats.log"
JAR_FILE="$jar_file"

echo "✅ JAR file: \$JAR_FILE"
echo "✅ Working directory: \$(pwd)"
echo "Starting \$SERVICE_NAME from JAR (Fast Mode)..."
echo "Service will run in this terminal window."
echo "Close this window or press Ctrl+C to stop the service."
echo "----------------------------------------"

# Track startup time
START_TIME=\$(date +%s)
echo "🕐 Startup began at: \$(date)"

# Function to check if Spring Boot has started
check_spring_boot_started() {
    if [[ -f "\$LOG_FILE" ]]; then
        # Look for Spring Boot startup completion indicators
        if grep -q "Started.*in.*seconds" "\$LOG_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -q "Tomcat started on port" "\$LOG_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -q "Application startup completed" "\$LOG_FILE" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Background process to monitor startup completion
(
    while ! check_spring_boot_started; do
        sleep 1
    done
    END_TIME=\$(date +%s)
    STARTUP_DURATION=\$((END_TIME - START_TIME))
    echo ""
    echo "🎉 =================================="
    echo "🚀 \$SERVICE_NAME startup completed!"
    echo "⏱️  Startup time: \${STARTUP_DURATION} seconds"
    echo "🕐 Started at: \$(date -r \$START_TIME)"
    echo "🏁 Completed at: \$(date -r \$END_TIME)"
    echo "===================================="
    echo ""
    
    # Also write to a startup stats file
    echo "\$(date -r \$END_TIME): \$SERVICE_NAME (JAR) started in \${STARTUP_DURATION}s" >> "\$STATS_FILE"
) &

echo "🚀 Performance: JAR execution with optimized JVM settings"
echo "🔧 JVM flags: G1GC, String deduplication, Fast startup"

# Optimized JVM settings for JAR execution - even faster than Maven
java -Xms1g -Xmx3g \\
     -XX:+UseG1GC \\
     -XX:TieredStopAtLevel=1 \\
     -XX:+UseStringDeduplication \\
     -XX:+AlwaysPreTouch \\
     -noverify \\
     -XX:+ParallelRefProcEnabled \\
     -XX:MaxGCPauseMillis=200 \\
     -Dspring.main.lazy-initialization=true \\
     -jar "\$JAR_FILE" 2>&1 | tee "\$LOG_FILE"
EOF
    chmod +x "$run_script"
    
    # Start in new terminal and capture the terminal process PID
    if command -v osascript >/dev/null 2>&1; then
        # macOS - use Terminal.app, starting in the service directory
        osascript -e "tell application \"Terminal\" to do script \"cd '$folder' && $run_script; echo 'Service stopped. You can close this window.'; read -p 'Press Enter to close...'\"" >/dev/null 2>&1 &
        local terminal_pid=$!
        
        # Wait a moment for the service to start
        sleep 2  # JAR startup is faster, so less wait time needed
        
        # Find the Java process using helper function (JAR shows up as java process)
        local java_pid=""
        local attempts=0
        while [[ -z "$java_pid" && $attempts -lt 8 ]]; do
            java_pid=$(find_service_processes "$folder" | head -1)
            
            if [[ -z "$java_pid" ]]; then
                sleep 1
                ((attempts++))
            fi
        done
        
        if [[ -n "$java_pid" ]]; then
            echo $java_pid > "$pid_file"
            echo -e "${GREEN}✅ Started $service_name from JAR (PID: $java_pid) - FAST MODE${NC}"
        else
            echo -e "${YELLOW}⚠️  $service_name terminal opened, waiting for Java startup...${NC}"
            # Create a placeholder PID file with terminal PID for tracking
            echo $terminal_pid > "$pid_file"
        fi
    else
        # Fallback for non-macOS systems - try gnome-terminal or xterm
        if command -v gnome-terminal >/dev/null 2>&1; then
            gnome-terminal -- bash "$run_script" &
        elif command -v xterm >/dev/null 2>&1; then
            xterm -e "bash $run_script" &
        else
            echo -e "${RED}❌ No suitable terminal emulator found${NC}"
            echo -e "${YELLOW}Run manually: cd $folder && java -jar $jar_file${NC}"
            return 1
        fi
        
        local terminal_pid=$!
        sleep 2
        echo $terminal_pid > "$pid_file"
        echo -e "${GREEN}✅ Started $service_name from JAR (PID: $terminal_pid) - FAST MODE${NC}"
    fi
}

# Function to start a single service
start_service() {
    local folder="$1"
    local service_name=$(basename "$folder")
    
    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}❌ Error: Directory $folder does not exist${NC}"
        return 1
    fi
    
    if [[ ! -f "$folder/pom.xml" ]]; then
        echo -e "${RED}❌ Error: No pom.xml found in $folder${NC}"
        return 1
    fi
    
    # Check if already running
    local pid_file="$PID_DIR/$service_name.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  $service_name is already running (PID: $pid)${NC}"
            return 0
        fi
    fi
    
    echo -e "${BLUE}🔄 Starting $service_name in new terminal...${NC}"
    
    # Create a script to run in the new terminal
    local run_script="$PID_DIR/run_$service_name.sh"
    cat > "$run_script" << EOF
#!/bin/bash

# Service configuration
SERVICE_NAME="$service_name"
LOG_FILE="$PID_DIR/$service_name.log"
STATS_FILE="$PID_DIR/startup_stats.log"

# Source shell profile to ensure environment is loaded
if [[ -f ~/.zshrc ]]; then
    source ~/.zshrc
elif [[ -f ~/.bash_profile ]]; then
    source ~/.bash_profile
elif [[ -f ~/.bashrc ]]; then
    source ~/.bashrc
fi

# Ensure Java environment is properly set - FORCE JDK usage
export JAVA_HOME="/Library/Java/JavaVirtualMachines/sapmachine-21.jdk/Contents/Home"
export PATH="\$JAVA_HOME/bin:\$PATH"

# Verify we're using JDK not JRE
if [[ "\$JAVA_HOME" == *".jre"* ]]; then
    echo "⚠️  Warning: JAVA_HOME points to JRE, switching to JDK"
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/sapmachine-21.jdk/Contents/Home"
    export PATH="\$JAVA_HOME/bin:\$PATH"
fi

echo "✅ Working directory: \$(pwd)"
echo "✅ Java version: \$(java -version 2>&1 | head -1)"
echo "✅ Java compiler: \$(which javac 2>/dev/null || echo 'Not found')"
echo "✅ JAVA_HOME: \$JAVA_HOME"
echo "Starting \$SERVICE_NAME..."
echo "Service will run in this terminal window."
echo "Close this window or press Ctrl+C to stop the service."
echo "----------------------------------------"

# Validate pom.xml exists in current directory
if [[ ! -f "pom.xml" ]]; then
    echo "❌ Error: pom.xml not found in \$(pwd)"
    echo "❌ Make sure you're in the correct service directory"
    exit 1
fi

# Track startup time
START_TIME=\$(date +%s)
echo "🕐 Startup began at: \$(date)"

# Function to check if Spring Boot has started
check_spring_boot_started() {
    if [[ -f "\$LOG_FILE" ]]; then
        # Look for Spring Boot startup completion indicators
        if grep -q "Started.*in.*seconds" "\$LOG_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -q "Tomcat started on port" "\$LOG_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -q "Application startup completed" "\$LOG_FILE" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Background process to monitor startup completion
(
    while ! check_spring_boot_started; do
        sleep 1
    done
    END_TIME=\$(date +%s)
    STARTUP_DURATION=\$((END_TIME - START_TIME))
    echo ""
    echo "🎉 =================================="
    echo "🚀 \$SERVICE_NAME startup completed!"
    echo "⏱️  Startup time: \${STARTUP_DURATION} seconds"
    echo "🕐 Started at: \$(date -r \$START_TIME)"
    echo "🏁 Completed at: \$(date -r \$END_TIME)"
    echo "===================================="
    echo ""
    
    # Also write to a startup stats file
    echo "\$(date -r \$END_TIME): \$SERVICE_NAME started in \${STARTUP_DURATION}s" >> "\$STATS_FILE"
) &

# Start Spring Boot with output to both console and log file
echo "🔧 Maven configuration:"
echo "   JAVA_HOME: \$JAVA_HOME"
echo "   Java executable: \$(which java)"
echo "   Javac executable: \$(which javac)"

# Force Maven to use the correct Java compiler with multiple approaches
JAVAC_PATH="\$JAVA_HOME/bin/javac"

# Performance-optimized Maven and JVM settings
# Use G1GC for better Spring Boot performance and faster startup
export MAVEN_OPTS="-Xms1g -Xmx3g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:+AlwaysPreTouch -XX:TieredStopAtLevel=1 -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -Dmaven.compiler.fork=true -Dmaven.compiler.executable=\$JAVAC_PATH"
export JAVA_HOME_FOR_MAVEN="\$JAVA_HOME"

echo "🔧 Using javac at: \$JAVAC_PATH"
echo "🚀 Performance optimizations enabled (G1GC, String deduplication, Fast JIT)"

# Verify javac exists before proceeding
if [[ ! -f "\$JAVAC_PATH" ]]; then
    echo "❌ Error: javac not found at \$JAVAC_PATH"
    echo "❌ Available Java installations:"
    ls -la /Library/Java/JavaVirtualMachines/
    exit 1
fi

# Optimized Maven spring-boot:run with development-focused JVM flags
mvn -Djava.home="\$JAVA_HOME" \\
    -Dmaven.compiler.fork=true \\
    -Dmaven.compiler.executable="\$JAVAC_PATH" \\
    -Dmaven.compiler.compilerVersion=21 \\
    -Dmaven.test.skip=true \\
    -Dspring-boot.run.fork=true \\
    -Dspring-boot.run.jvmArguments="-Xms1g -Xmx3g -XX:+UseG1GC -XX:TieredStopAtLevel=1 -XX:+UseStringDeduplication -XX:+AlwaysPreTouch -noverify -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200" \\
    spring-boot:run 2>&1 | tee "\$LOG_FILE"
EOF
    chmod +x "$run_script"
    
    # Start in new terminal and capture the terminal process PID
    if command -v osascript >/dev/null 2>&1; then
        # macOS - use Terminal.app, starting in the service directory
        osascript -e "tell application \"Terminal\" to do script \"cd '$folder' && $run_script; echo 'Service stopped. You can close this window.'; read -p 'Press Enter to close...'\"" >/dev/null 2>&1 &
        local terminal_pid=$!
        
        # Wait a moment for the service to start
        sleep 3
        
        # Find the mvn process using helper function
        local mvn_pid=""
        local attempts=0
        while [[ -z "$mvn_pid" && $attempts -lt 10 ]]; do
            mvn_pid=$(find_service_processes "$folder" | head -1)
            
            if [[ -z "$mvn_pid" ]]; then
                sleep 1
                ((attempts++))
            fi
        done
        
        if [[ -n "$mvn_pid" ]]; then
            echo $mvn_pid > "$pid_file"
            echo -e "${GREEN}✅ Started $service_name in terminal (PID: $mvn_pid)${NC}"
        else
            echo -e "${YELLOW}⚠️  $service_name terminal opened, waiting for Maven startup...${NC}"
            # Create a placeholder PID file with terminal PID for tracking
            echo $terminal_pid > "$pid_file"
        fi
    else
        # Fallback for non-macOS systems - try gnome-terminal or xterm
        if command -v gnome-terminal >/dev/null 2>&1; then
            gnome-terminal -- bash "$run_script" &
        elif command -v xterm >/dev/null 2>&1; then
            xterm -e "bash $run_script" &
        else
            echo -e "${RED}❌ No suitable terminal emulator found${NC}"
            echo -e "${YELLOW}Run manually: cd $folder && mvn spring-boot:run${NC}"
            return 1
        fi
        
        local terminal_pid=$!
        sleep 2
        echo $terminal_pid > "$pid_file"
        echo -e "${GREEN}✅ Started $service_name in terminal (PID: $terminal_pid)${NC}"
    fi
}

# Function to stop a single service
stop_service() {
    local folder="$1"
    local service_name=$(basename "$folder")
    local pid_file="$PID_DIR/$service_name.pid"
    local run_script="$PID_DIR/run_$service_name.sh"
    
    if [[ ! -f "$pid_file" ]]; then
        echo -e "${YELLOW}⚠️  $service_name is not running${NC}"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    # First try to find and kill the actual mvn/java process using helper function
    local mvn_pids=$(find_service_processes "$folder")
    
    if [[ -n "$mvn_pids" ]]; then
        echo -e "${BLUE}🔄 Stopping $service_name (Maven/Java process)...${NC}"
        for mvn_pid in $mvn_pids; do
            kill "$mvn_pid" 2>/dev/null
            
            # Wait for process to stop
            local count=0
            while ps -p "$mvn_pid" > /dev/null 2>&1 && [[ $count -lt 15 ]]; do
                sleep 1
                ((count++))
            done
            
            if ps -p "$mvn_pid" > /dev/null 2>&1; then
                echo -e "${YELLOW}⚠️  Force killing process (PID: $mvn_pid)...${NC}"
                kill -9 "$mvn_pid" 2>/dev/null
                sleep 1
            fi
        done
        echo -e "${GREEN}✅ Stopped $service_name${NC}"
    else
        # Fallback: try to kill the terminal/recorded PID
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${BLUE}🔄 Stopping $service_name terminal (PID: $pid)...${NC}"
            kill "$pid" 2>/dev/null
            echo -e "${GREEN}✅ Stopped $service_name terminal${NC}"
        else
            echo -e "${YELLOW}⚠️  $service_name was not running${NC}"
        fi
    fi
    
    # Clean up files
    rm -f "$pid_file"
    rm -f "$run_script"
}

# Function to start all services
start_all_services() {
    if [[ -z "$CURRENT_RUN_FILE" ]]; then
        echo -e "${RED}❌ No run scenario selected${NC}"
        echo -e "${YELLOW}Please select a run scenario first${NC}"
        return 1
    fi
    
    echo -e "${WHITE}🚀 Starting all services in scenario: ${CYAN}$CURRENT_RUN_SCENARIO${NC}"
    echo ""
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            start_service "$folder"
        fi
    done < "$CURRENT_RUN_FILE"
    
    echo ""
    echo -e "${GREEN}🎉 All services in $CURRENT_RUN_SCENARIO scenario started!${NC}"
}

# Function to stop all services
stop_all_services() {
    echo -e "${WHITE}🛑 Stopping all running services...${NC}"
    echo ""
    
    for pid_file in "$PID_DIR"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local service_name=$(basename "$pid_file" .pid)
            
            # Find folder for this service (check current scenario first, then build folders)
            local service_folder=""
            
            # Check current run scenario
            if [[ -n "$CURRENT_RUN_FILE" ]]; then
                while IFS= read -r folder || [[ -n "$folder" ]]; do
                    if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
                        if [[ "$(basename "$folder")" == "$service_name" ]]; then
                            service_folder="$folder"
                            break
                        fi
                    fi
                done < "$CURRENT_RUN_FILE"
            fi
            
            # If not found in current scenario, check build folders
            if [[ -z "$service_folder" && -f "$BUILD_FOLDERS_FILE" ]]; then
                while IFS= read -r folder || [[ -n "$folder" ]]; do
                    if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
                        if [[ "$(basename "$folder")" == "$service_name" ]]; then
                            service_folder="$folder"
                            break
                        fi
                    fi
                done < "$BUILD_FOLDERS_FILE"
            fi
            
            if [[ -n "$service_folder" ]]; then
                stop_service "$service_folder"
            else
                echo -e "${YELLOW}⚠️  Could not find folder for $service_name, stopping by PID only${NC}"
                # Fallback: stop by PID file only
                local pid=$(cat "$pid_file")
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill "$pid" 2>/dev/null
                    echo -e "${GREEN}✅ Stopped $service_name${NC}"
                fi
                rm -f "$pid_file"
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}🎉 All services stopped!${NC}"
}

# Function to git pull a single service
git_pull_service() {
    local folder="$1"
    local service_name=$(basename "$folder")
    
    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}❌ Error: Directory $folder does not exist${NC}"
        return 1
    fi
    
    cd "$folder"
    
    if [[ ! -d ".git" ]]; then
        echo -e "${YELLOW}⚠️  $service_name is not a git repository, skipping...${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔄 Git pulling $service_name...${NC}"
    
    if git pull; then
        echo -e "${GREEN}✅ Git pull successful for $service_name${NC}"
    else
        echo -e "${RED}❌ Git pull failed for $service_name${NC}"
        return 1
    fi
}

# Function to clean install a single service (includes JAR generation)
clean_install_service() {
    local folder="$1"
    local service_name=$(basename "$folder")
    
    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}❌ Error: Directory $folder does not exist${NC}"
        return 1
    fi
    
    cd "$folder"
    
    if [[ ! -f "pom.xml" ]]; then
        echo -e "${YELLOW}⚠️  No pom.xml found in $service_name, skipping...${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔄 Clean installing $service_name (with JAR generation)...${NC}"
    
    # Use 'package' instead of 'install' to ensure JAR creation, skip tests for speed
    if mvn clean package -DskipTests -Dmaven.compiler.fork=true; then
        # Check if JAR was created
        local jar_file=$(find target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" 2>/dev/null | head -1)
        if [[ -n "$jar_file" ]]; then
            echo -e "${GREEN}✅ Clean install successful for $service_name${NC}"
            echo -e "${CYAN}🏗️  JAR created: $(basename "$jar_file") (ready for fast startup)${NC}"
        else
            echo -e "${GREEN}✅ Clean install successful for $service_name${NC}"
            echo -e "${YELLOW}⚠️  JAR not found in expected location${NC}"
        fi
    else
        echo -e "${RED}❌ Clean install failed for $service_name${NC}"
        return 1
    fi
}

# Function to git pull all services
git_pull_all_services() {
    local config_file=""
    local config_display=""
    
    if [[ "$BUILD_CONFIG_MODE" == "run_scenario" ]]; then
        if [[ -z "$CURRENT_RUN_FILE" ]]; then
            echo -e "${RED}❌ No run scenario selected${NC}"
            echo -e "${YELLOW}Please select a run scenario first or switch to build_folders mode${NC}"
            return 1
        fi
        config_file="$CURRENT_RUN_FILE"
        config_display="$CURRENT_RUN_SCENARIO scenario"
    else
        if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
            echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
            echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
            return 1
        fi
        config_file="$BUILD_FOLDERS_FILE"
        config_display="build_folders.txt"
    fi
    
    echo -e "${WHITE}📥 Git pulling all services from: ${CYAN}$config_display${NC}"
    echo ""
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            ((total_count++))
            if git_pull_service "$folder"; then
                ((success_count++))
            fi
            echo ""
        fi
    done < "$config_file"
    
    echo -e "${CYAN}📊 Git pull summary: ${success_count}/${total_count} services updated successfully${NC}"
}

# Function to clean install all services
clean_install_all_services() {
    local config_file=""
    local config_display=""
    
    if [[ "$BUILD_CONFIG_MODE" == "run_scenario" ]]; then
        if [[ -z "$CURRENT_RUN_FILE" ]]; then
            echo -e "${RED}❌ No run scenario selected${NC}"
            echo -e "${YELLOW}Please select a run scenario first or switch to build_folders mode${NC}"
            return 1
        fi
        config_file="$CURRENT_RUN_FILE"
        config_display="$CURRENT_RUN_SCENARIO scenario"
    else
        if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
            echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
            echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
            return 1
        fi
        config_file="$BUILD_FOLDERS_FILE"
        config_display="build_folders.txt"
    fi
    
    echo -e "${WHITE}🔨 Clean installing all services from: ${CYAN}$config_display${NC}"
    echo ""
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            ((total_count++))
            if clean_install_service "$folder"; then
                ((success_count++))
            fi
            echo ""
        fi
    done < "$config_file"
    
    echo -e "${CYAN}📊 Clean install summary: ${success_count}/${total_count} services built successfully${NC}"
}

# Function to pull and build all services (like original script)
pull_and_build_all() {
    local config_file=""
    local config_display=""
    
    if [[ "$BUILD_CONFIG_MODE" == "run_scenario" ]]; then
        if [[ -z "$CURRENT_RUN_FILE" ]]; then
            echo -e "${RED}❌ No run scenario selected${NC}"
            echo -e "${YELLOW}Please select a run scenario first or switch to build_folders mode${NC}"
            return 1
        fi
        config_file="$CURRENT_RUN_FILE"
        config_display="$CURRENT_RUN_SCENARIO scenario"
    else
        if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
            echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
            echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
            return 1
        fi
        config_file="$BUILD_FOLDERS_FILE"
        config_display="build_folders.txt"
    fi
    
    echo -e "${WHITE}🔄 Pull and build all services from: ${CYAN}$config_display${NC}"
    echo ""
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            local service_name=$(basename "$folder")
            echo -e "${PURPLE}========================================${NC}"
            echo -e "${WHITE}Processing: $service_name${NC}"
            echo -e "${PURPLE}========================================${NC}"
            
            ((total_count++))
            
            if git_pull_service "$folder" && clean_install_service "$folder"; then
                ((success_count++))
                echo -e "${GREEN}✅ Successfully processed: $service_name${NC}"
            else
                echo -e "${RED}❌ Failed to process: $service_name${NC}"
            fi
            echo ""
        fi
    done < "$config_file"
    
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}📊 Final summary: ${success_count}/${total_count} services processed successfully${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# Function to build JARs for all services (faster startup alternative)
build_jars_all_services() {
    local config_file=""
    local config_display=""
    
    if [[ "$BUILD_CONFIG_MODE" == "run_scenario" ]]; then
        if [[ -z "$CURRENT_RUN_FILE" ]]; then
            echo -e "${RED}❌ No run scenario selected${NC}"
            echo -e "${YELLOW}Please select a run scenario first or switch to build_folders mode${NC}"
            return 1
        fi
        config_file="$CURRENT_RUN_FILE"
        config_display="$CURRENT_RUN_SCENARIO scenario"
    else
        if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
            echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
            echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
            return 1
        fi
        config_file="$BUILD_FOLDERS_FILE"
        config_display="build_folders.txt"
    fi
    
    echo -e "${WHITE}🏗️  Building executable JARs for all services from: ${CYAN}$config_display${NC}"
    echo -e "${YELLOW}💡 This packages compiled sources into JARs for faster service startup${NC}"
    echo -e "${CYAN}Note: Sources must be already compiled (use clean install if unsure)${NC}"
    echo ""
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            local service_name=$(basename "$folder")
            echo -e "${PURPLE}========================================${NC}"
            echo -e "${WHITE}Building JAR: $service_name${NC}"
            echo -e "${PURPLE}========================================${NC}"
            
            ((total_count++))
            
            if [[ ! -d "$folder" ]]; then
                echo -e "${RED}❌ Error: Directory $folder does not exist${NC}"
                continue
            fi
            
            cd "$folder"
            
            if [[ ! -f "pom.xml" ]]; then
                echo -e "${YELLOW}⚠️  No pom.xml found in $service_name, skipping...${NC}"
                continue
            fi
            
            echo -e "${BLUE}🔄 Building JAR for $service_name...${NC}"
            
            if mvn package -DskipTests -Dmaven.compiler.fork=true; then
                ((success_count++))
                # Check if JAR was created
                local jar_file=$(find target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" | head -1)
                if [[ -n "$jar_file" ]]; then
                    echo -e "${GREEN}✅ JAR created: $jar_file${NC}"
                else
                    echo -e "${YELLOW}⚠️  JAR built but not found in expected location${NC}"
                fi
            else
                echo -e "${RED}❌ JAR build failed for $service_name${NC}"
            fi
            echo ""
        fi
    done < "$config_file"
    
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}📊 JAR build summary: ${success_count}/${total_count} services built successfully${NC}"
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}🚀 Services with JARs can now be started faster using JAR mode${NC}"
    fi
    echo -e "${PURPLE}========================================${NC}"
}

# Function to pull and build all services in parallel
pull_and_build_all_parallel() {
    local config_file=""
    local config_display=""
    
    if [[ "$BUILD_CONFIG_MODE" == "run_scenario" ]]; then
        if [[ -z "$CURRENT_RUN_FILE" ]]; then
            echo -e "${RED}❌ No run scenario selected${NC}"
            echo -e "${YELLOW}Please select a run scenario first or switch to build_folders mode${NC}"
            return 1
        fi
        config_file="$CURRENT_RUN_FILE"
        config_display="$CURRENT_RUN_SCENARIO scenario"
    else
        if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
            echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
            echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
            return 1
        fi
        config_file="$BUILD_FOLDERS_FILE"
        config_display="build_folders.txt"
    fi
    
    echo -e "${WHITE}🔄 Pull and build all services in parallel from: ${CYAN}$config_display${NC}"
    echo ""
    
    # First, collect all valid folders
    local folders=()
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            folders+=("$folder")
        fi
    done < "$config_file"
    
    if [[ ${#folders[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No services found in configuration${NC}"
        return 1
    fi
    
    local total_count=${#folders[@]}
    echo -e "${CYAN}🚀 Starting parallel operations for $total_count services...${NC}"
    echo ""
    
    # Start all git pull operations in parallel
    echo -e "${BLUE}📥 Phase 1: Git pull operations${NC}"
    local pull_pids=()
    local pull_logs=()
    
    for folder in "${folders[@]}"; do
        local service_name=$(basename "$folder")
        local pull_log="/tmp/pull_${service_name}_$$.log"
        pull_logs+=("$pull_log")
        
        echo -e "${YELLOW}  🔄 Starting git pull for $service_name...${NC}"
        
        # Run git pull in background, saving output to log file
        (
            cd "$folder" 2>/dev/null || {
                echo "❌ Error: Directory $folder does not exist" > "$pull_log"
                exit 1
            }
            
            if [[ ! -d ".git" ]]; then
                echo "⚠️  $service_name is not a git repository, skipping..." > "$pull_log"
                exit 0
            fi
            
            echo "🔄 Git pulling $service_name..." > "$pull_log"
            if git pull >> "$pull_log" 2>&1; then
                echo "✅ Git pull successful for $service_name" >> "$pull_log"
                exit 0
            else
                echo "❌ Git pull failed for $service_name" >> "$pull_log"
                exit 1
            fi
        ) &
        
        pull_pids+=($!)
    done
    
    # Wait for all git pull operations to complete
    echo ""
    echo -e "${CYAN}⏳ Waiting for all git pull operations to complete...${NC}"
    
    local pull_success_count=0
    for i in "${!pull_pids[@]}"; do
        local pid=${pull_pids[$i]}
        local service_name=$(basename "${folders[$i]}")
        local pull_log=${pull_logs[$i]}
        
        wait $pid
        local exit_code=$?
        
        # Show results
        if [[ $exit_code -eq 0 ]]; then
            ((pull_success_count++))
            echo -e "${GREEN}  ✅ $service_name: $(tail -1 "$pull_log")${NC}"
        else
            echo -e "${RED}  ❌ $service_name: $(tail -1 "$pull_log")${NC}"
        fi
        
        # Clean up log file
        rm -f "$pull_log"
    done
    
    echo ""
    echo -e "${CYAN}📊 Git pull summary: ${pull_success_count}/${total_count} services updated successfully${NC}"
    echo ""
    
    # Start all Maven clean install operations in parallel
    echo -e "${BLUE}🔨 Phase 2: Maven clean install operations${NC}"
    local build_pids=()
    local build_logs=()
    
    for folder in "${folders[@]}"; do
        local service_name=$(basename "$folder")
        local build_log="/tmp/build_${service_name}_$$.log"
        build_logs+=("$build_log")
        
        echo -e "${YELLOW}  🔄 Starting clean install for $service_name...${NC}"
        
        # Run Maven clean install in background, saving output to log file
        (
            cd "$folder" 2>/dev/null || {
                echo "❌ Error: Directory $folder does not exist" > "$build_log"
                exit 1
            }
            
            if [[ ! -f "pom.xml" ]]; then
                echo "⚠️  No pom.xml found in $service_name, skipping..." > "$build_log"
                exit 0
            fi
            
            echo "🔄 Clean installing $service_name (with JAR generation)..." > "$build_log"
            if mvn clean package -DskipTests -Dmaven.compiler.fork=true >> "$build_log" 2>&1; then
                # Check if JAR was created and add to log
                local jar_file=$(find target -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" 2>/dev/null | head -1)
                if [[ -n "$jar_file" ]]; then
                    echo "✅ Clean install successful for $service_name - JAR: $(basename "$jar_file")" >> "$build_log"
                else
                    echo "✅ Clean install successful for $service_name - JAR not found" >> "$build_log"
                fi
                exit 0
            else
                echo "❌ Clean install failed for $service_name" >> "$build_log"
                exit 1
            fi
        ) &
        
        build_pids+=($!)
    done
    
    # Wait for all Maven operations to complete
    echo ""
    echo -e "${CYAN}⏳ Waiting for all Maven clean install operations to complete...${NC}"
    
    local build_success_count=0
    for i in "${!build_pids[@]}"; do
        local pid=${build_pids[$i]}
        local service_name=$(basename "${folders[$i]}")
        local build_log=${build_logs[$i]}
        
        wait $pid
        local exit_code=$?
        
        # Show results
        if [[ $exit_code -eq 0 ]]; then
            ((build_success_count++))
            echo -e "${GREEN}  ✅ $service_name: $(tail -1 "$build_log")${NC}"
        else
            echo -e "${RED}  ❌ $service_name: $(tail -1 "$build_log")${NC}"
        fi
        
        # Clean up log file
        rm -f "$build_log"
    done
    
    echo ""
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}📊 Final summary:${NC}"
    echo -e "${CYAN}  Git pull: ${pull_success_count}/${total_count} services updated successfully${NC}"
    echo -e "${CYAN}  Maven build: ${build_success_count}/${total_count} services built successfully${NC}"
    echo -e "${CYAN}  Overall: $((pull_success_count < build_success_count ? pull_success_count : build_success_count))/${total_count} services fully processed${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# Function to show startup statistics
show_startup_stats() {
    local stats_file="$PID_DIR/startup_stats.log"
    
    echo -e "${WHITE}📊 Startup Statistics:${NC}"
    echo ""
    
    if [[ -f "$stats_file" ]]; then
        echo -e "${CYAN}Recent startup times:${NC}"
        echo ""
        tail -20 "$stats_file" | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
        
        # Calculate average startup time if there are stats
        local avg_time=$(awk -F'started in |s' '{sum += $2; count++} END {if(count > 0) printf "%.1f", sum/count; else print "N/A"}' "$stats_file")
        local total_starts=$(wc -l < "$stats_file" | xargs)
        
        echo -e "${GREEN}📈 Summary:${NC}"
        echo "  Total service starts: $total_starts"
        echo "  Average startup time: ${avg_time}s"
        echo ""
    else
        echo -e "${YELLOW}No startup statistics available yet${NC}"
        echo -e "${CYAN}Start some services to begin collecting startup time data${NC}"
        echo ""
    fi
    
    echo -n "Press Enter to continue..."
    read -r
}

# Function to show logs
show_logs() {
    echo -e "${WHITE}📋 Available log files:${NC}"
    echo ""
    
    local log_files=("$PID_DIR"/*.log)
    if [[ -f "${log_files[0]}" ]]; then
        local i=1
        for log_file in "${log_files[@]}"; do
            if [[ -f "$log_file" ]]; then
                local service_name=$(basename "$log_file" .log)
                echo "  $i) $service_name"
                ((i++))
            fi
        done
        
        echo ""
        echo -n "Enter number to view log (or press Enter to return): "
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -lt $i ]]; then
            local selected_log=($(ls "$PID_DIR"/*.log 2>/dev/null))
            local log_file="${selected_log[$((choice-1))]}"
            
            echo ""
            echo -e "${CYAN}📄 Showing last 50 lines of $(basename "$log_file"):${NC}"
            echo ""
            tail -50 "$log_file" | cat
            echo ""
            echo -n "Press Enter to continue..."
            read -r
        fi
    else
        echo -e "${YELLOW}No log files found${NC}"
        echo ""
        echo -n "Press Enter to continue..."
        read -r
    fi
}

# Function to show individual service menu
service_menu() {
    local folder="$1"
    local service_name=$(basename "$folder")
    
    while true; do
        show_header
        echo -e "${WHITE}🔧 Managing: ${CYAN}$service_name${NC}"
        echo ""
        
        local status=$(get_service_status "$folder" true)
        echo -e "Status: $status"
        echo ""
        
        echo "1) Start service (Maven)"
        echo "2) Start service (JAR - faster)"
        echo "3) Stop service"
        echo "4) Restart service"
        echo "5) Git pull service"
        echo "6) Clean install service (+ JAR)"
        echo "7) Pull and build service (+ JAR)"
        echo "8) View logs"
        echo "9) Back to main menu"
        echo ""
        echo -n "Choose an option [1-9]: "
        read -r choice
        
        case $choice in
            1)
                echo ""
                start_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                echo ""
                start_service_jar "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            3)
                echo ""
                stop_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            4)
                echo ""
                stop_service "$folder"
                sleep 2
                start_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            5)
                echo ""
                git_pull_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            6)
                echo ""
                clean_install_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            7)
                echo ""
                echo -e "${WHITE}🔄 Pull and build $service_name...${NC}"
                echo ""
                if git_pull_service "$folder" && clean_install_service "$folder"; then
                    echo -e "${GREEN}✅ Successfully processed $service_name${NC}"
                else
                    echo -e "${RED}❌ Failed to process $service_name${NC}"
                fi
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            8)
                local log_file="$PID_DIR/$service_name.log"
                if [[ -f "$log_file" ]]; then
                    clear
                    echo -e "${CYAN}📄 Last 50 lines of $service_name log:${NC}"
                    echo ""
                    tail -50 "$log_file" | cat
                    echo ""
                    echo -n "Press Enter to continue..."
                    read -r
                else
                    echo ""
                    echo -e "${YELLOW}No log file found for $service_name${NC}"
                    echo -n "Press Enter to continue..."
                    read -r
                fi
                ;;
            9)
                break
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to show individual services menu
individual_services_menu() {
    if [[ -z "$CURRENT_RUN_FILE" ]]; then
        echo -e "${RED}❌ No run scenario selected${NC}"
        echo -e "${YELLOW}Please select a run scenario first${NC}"
        echo -n "Press Enter to continue..."
        read -r
        return
    fi
    
    while true; do
        show_header
        echo -e "${WHITE}🔧 Individual Service Management - Scenario: ${CYAN}$CURRENT_RUN_SCENARIO${NC}"
        echo ""
        
        local services=()
        local i=1
        
        while IFS= read -r folder || [[ -n "$folder" ]]; do
            if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
                local service_name=$(basename "$folder")
                local status=$(get_service_status "$folder" true)
                
                services+=("$folder")
                printf "  %d) %-30s %s\n" "$i" "$service_name" "$status"
                ((i++))
            fi
        done < "$CURRENT_RUN_FILE"
        
        echo ""
        echo "  0) Back to main menu"
        echo ""
        echo -n "Choose a service [0-$((i-1))]: "
        read -r choice
        
        if [[ "$choice" == "0" ]]; then
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -lt $i ]]; then
            service_menu "${services[$((choice-1))]}"
        else
            echo ""
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 1
        fi
    done
}

# Main menu function
main_menu() {
    while true; do
        show_header
        show_status
        
        # Show default configuration status
        echo -e "${WHITE}⚙️  Default Configuration:${NC}"
        if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
            local default_scenario=""
            local default_build_mode=""
            
            while IFS='=' read -r key value; do
                case $key in
                    DEFAULT_RUN_SCENARIO)
                        default_scenario="$value"
                        ;;
                    DEFAULT_BUILD_MODE)
                        default_build_mode="$value"
                        ;;
                esac
            done < "$DEFAULT_CONFIG_FILE"
            
            echo -e "${CYAN}  📋 Default profile: ${default_scenario:-None} | 🔨 Build mode: ${default_build_mode:-None}${NC}"
        else
            echo -e "${YELLOW}  No default configuration set${NC}"
        fi
        echo ""
        
        echo -e "${WHITE}📋 Main Menu:${NC}"
        echo ""
        echo -e "${CYAN}🎯 Scenario Management:${NC}"
        echo "1) Select run scenario"
        echo "2) Select build configuration"
        echo "3) Manage default configuration"
        echo ""
        echo -e "${CYAN}🚀 Service Operations:${NC}"
        echo "4) Start all services"
        echo "5) Stop all services"
        echo "6) Restart all services"
        echo "7) Manage individual services"
        echo ""
        
        # Show current build configuration
        local build_display=""
        if [[ "$BUILD_CONFIG_MODE" == "build_folders" ]]; then
            build_display="build_folders.txt"
        elif [[ "$BUILD_CONFIG_MODE" == "run_scenario" && -n "$CURRENT_RUN_SCENARIO" ]]; then
            build_display="$CURRENT_RUN_SCENARIO scenario"
        else
            build_display="run_scenario (none selected)"
        fi
        
        echo -e "${CYAN}🔨 Build Operations:${NC} ${YELLOW}(using: $build_display)${NC}"
        echo "8) Git pull all services"
        echo "9) Clean install all services (+ JARs)"
        echo "10) Pull and build all services (sequential + JARs)"
        echo "11) Pull and build all services (parallel + JARs)"
        echo "12) Build JARs only (if already compiled)"
        echo ""
        echo -e "${CYAN}📊 Monitoring:${NC}"
        echo "13) View logs"
        echo "14) View startup statistics"
        echo "15) Refresh status (quick)"
        echo "16) Thorough status check"
        echo "17) Exit"
        echo ""
        echo -n "Choose an option [1-17]: "
        read -r choice
        
        case $choice in
            1)
                select_run_scenario
                ;;
            2)
                select_build_config
                ;;
            3)
                manage_default_config
                ;;
            4)
                echo ""
                start_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            5)
                echo ""
                stop_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            6)
                echo ""
                stop_all_services
                echo ""
                echo -e "${BLUE}⏱️  Waiting 3 seconds before restart...${NC}"
                sleep 3
                echo ""
                start_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            7)
                individual_services_menu
                ;;
            8)
                echo ""
                git_pull_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            9)
                echo ""
                clean_install_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            10)
                echo ""
                pull_and_build_all
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            11)
                echo ""
                pull_and_build_all_parallel
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            12)
                echo ""
                build_jars_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            13)
                show_logs
                ;;
            14)
                show_startup_stats
                ;;
            15)
                # Just refresh by continuing the loop (quick mode)
                ;;
            16)
                echo ""
                echo -e "${BLUE}🔍 Performing thorough status check...${NC}"
                show_status true
                echo -n "Press Enter to continue..."
                read -r
                ;;
            17)
                echo ""
                echo -e "${GREEN}👋 Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -s|--set-default)
            if [[ -n "$2" ]]; then
                set_permanent_default "$2"
                exit 0
            else
                echo -e "${RED}❌ Error: --set-default requires a profile name${NC}"
                echo "Use: $0 --set-default PROFILE"
                exit 1
            fi
            ;;
        -c|--clear-default)
            clear_permanent_default
            exit 0
            ;;
        -l|--list-profiles)
            list_profiles
            exit 0
            ;;
        -d|--show-default)
            show_current_default
            exit 0
            ;;
        -*)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use: $0 --help for usage information"
            exit 1
            ;;
        *)
            # This should be a profile name
            if [[ -z "$PROFILE_FROM_CMDLINE" ]]; then
                PROFILE_FROM_CMDLINE="$1"
            else
                echo -e "${RED}❌ Error: Only one profile can be specified${NC}"
                echo "Use: $0 --help for usage information"
                exit 1
            fi
            ;;
    esac
    shift
done

# Check if any run scenario files exist
if [[ $(find "$SCRIPT_DIR" -name "run_*.txt" -type f | wc -l) -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No run scenario files found${NC}"
    echo -e "${CYAN}Please create run_*.txt files from the examples (e.g., run_core.txt, run_all.txt)${NC}"
    exit 1
fi

# Load profile from command line if specified
if [[ -n "$PROFILE_FROM_CMDLINE" ]]; then
    load_profile_from_cmdline "$PROFILE_FROM_CMDLINE"
else
    # Load default configuration if available
    load_default_config
fi

# Start the main menu
main_menu