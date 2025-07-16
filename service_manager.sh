#!/bin/bash

# Spring Boot Service Manager - Interactive Terminal UI
# Manages Spring Boot services with a simple menu interface

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_FOLDERS_FILE="$SCRIPT_DIR/build_folders.txt"
PID_DIR="$SCRIPT_DIR/pids"

# Current run scenario (set by user selection)
CURRENT_RUN_SCENARIO=""
CURRENT_RUN_FILE=""

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

# Function to clear screen and show header
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}              🚀 Spring Boot Service Manager              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to get service status
get_service_status() {
    local folder="$1"
    local service_name=$(basename "$folder")
    local pid_file="$PID_DIR/$service_name.pid"
    
    # First check if there's a running mvn process for this service
    local mvn_pids=$(pgrep -f "mvn spring-boot:run.*$service_name")
    if [[ -n "$mvn_pids" ]]; then
        local mvn_pid=$(echo "$mvn_pids" | head -1)
        # Update PID file with actual Maven PID
        echo "$mvn_pid" > "$pid_file"
        echo -e "${GREEN}●${NC} Running (PID: $mvn_pid)"
        return 0
    fi
    
    # Check PID file as fallback
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}●${NC} Terminal open (PID: $pid)"
        else
            echo -e "${RED}●${NC} Stopped (stale PID)"
            rm -f "$pid_file"
        fi
    else
        echo -e "${RED}●${NC} Stopped"
    fi
}

# Function to get available run scenarios
get_run_scenarios() {
    find "$SCRIPT_DIR" -name "run_*.txt" -type f | sort
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
    if [[ -z "$CURRENT_RUN_SCENARIO" ]]; then
        echo -e "${WHITE}📊 Service Status:${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  No run scenario selected${NC}"
        echo -e "${CYAN}Use 'Select Run Scenario' to choose services to manage${NC}"
        echo ""
        return
    fi
    
    echo -e "${WHITE}📊 Service Status - Scenario: ${CYAN}$CURRENT_RUN_SCENARIO${NC}"
    echo ""
    
    local running_count=0
    local total_count=0
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            local service_name=$(basename "$folder")
            local status=$(get_service_status "$folder")
            
            printf "  %-35s %s\n" "$service_name" "$status"
            
            if [[ "$status" == *"Running"* ]]; then
                ((running_count++))
            fi
            ((total_count++))
        fi
    done < "$CURRENT_RUN_FILE"
    
    echo ""
    echo -e "${CYAN}Summary: ${running_count}/${total_count} services running in $CURRENT_RUN_SCENARIO scenario${NC}"
    echo ""
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
cd "$folder"
echo "Starting $service_name..."
echo "Service will run in this terminal window."
echo "Close this window or press Ctrl+C to stop the service."
echo "----------------------------------------"

# Track startup time
START_TIME=\$(date +%s)
echo "🕐 Startup began at: \$(date)"

# Function to check if Spring Boot has started
check_spring_boot_started() {
    local log_file="$PID_DIR/$service_name.log"
    if [[ -f "\$log_file" ]]; then
        # Look for Spring Boot startup completion indicators
        if grep -q "Started.*in.*seconds" "\$log_file" 2>/dev/null; then
            return 0
        fi
        if grep -q "Tomcat started on port" "\$log_file" 2>/dev/null; then
            return 0
        fi
        if grep -q "Application startup completed" "\$log_file" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Start Spring Boot and capture output to log file
exec > >(tee "$PID_DIR/$service_name.log") 2>&1

# Background process to monitor startup completion
(
    while ! check_spring_boot_started; do
        sleep 1
    done
    END_TIME=\$(date +%s)
    STARTUP_DURATION=\$((END_TIME - START_TIME))
    echo ""
    echo "🎉 =================================="
    echo "🚀 $service_name startup completed!"
    echo "⏱️  Startup time: \${STARTUP_DURATION} seconds"
    echo "🕐 Started at: \$(date -r \$START_TIME)"
    echo "🏁 Completed at: \$(date -r \$END_TIME)"
    echo "===================================="
    echo ""
    
    # Also write to a startup stats file
    echo "\$(date -r \$END_TIME): $service_name started in \${STARTUP_DURATION}s" >> "$PID_DIR/startup_stats.log"
) &

mvn spring-boot:run
EOF
    chmod +x "$run_script"
    
    # Start in new terminal and capture the terminal process PID
    if command -v osascript >/dev/null 2>&1; then
        # macOS - use Terminal.app
        osascript -e "tell application \"Terminal\" to do script \"$run_script; echo 'Service stopped. You can close this window.'; read -p 'Press Enter to close...'\"" >/dev/null 2>&1 &
        local terminal_pid=$!
        
        # Wait a moment for the service to start
        sleep 3
        
        # Find the mvn process
        local mvn_pid=$(pgrep -f "mvn spring-boot:run.*$service_name" | head -1)
        if [[ -n "$mvn_pid" ]]; then
            echo $mvn_pid > "$pid_file"
            echo -e "${GREEN}✅ Started $service_name in terminal (PID: $mvn_pid)${NC}"
        else
            echo -e "${YELLOW}⚠️  $service_name terminal opened, waiting for startup...${NC}"
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
    
    # First try to find and kill the actual mvn process
    local mvn_pids=$(pgrep -f "mvn spring-boot:run.*$service_name")
    if [[ -n "$mvn_pids" ]]; then
        echo -e "${BLUE}🔄 Stopping $service_name (Maven process)...${NC}"
        for mvn_pid in $mvn_pids; do
            kill "$mvn_pid" 2>/dev/null
            
            # Wait for process to stop
            local count=0
            while ps -p "$mvn_pid" > /dev/null 2>&1 && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done
            
            if ps -p "$mvn_pid" > /dev/null 2>&1; then
                echo -e "${YELLOW}⚠️  Force killing Maven process...${NC}"
                kill -9 "$mvn_pid" 2>/dev/null
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

# Function to clean install a single service
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
    
    echo -e "${BLUE}🔄 Clean installing $service_name...${NC}"
    
    if mvn clean install; then
        echo -e "${GREEN}✅ Clean install successful for $service_name${NC}"
    else
        echo -e "${RED}❌ Clean install failed for $service_name${NC}"
        return 1
    fi
}

# Function to git pull all services
git_pull_all_services() {
    if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
        echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
        echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
        return 1
    fi
    
    echo -e "${WHITE}📥 Git pulling all build services...${NC}"
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
    done < "$BUILD_FOLDERS_FILE"
    
    echo -e "${CYAN}📊 Git pull summary: ${success_count}/${total_count} services updated successfully${NC}"
}

# Function to clean install all services
clean_install_all_services() {
    if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
        echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
        echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
        return 1
    fi
    
    echo -e "${WHITE}🔨 Clean installing all build services...${NC}"
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
    done < "$BUILD_FOLDERS_FILE"
    
    echo -e "${CYAN}📊 Clean install summary: ${success_count}/${total_count} services built successfully${NC}"
}

# Function to pull and build all services (like original script)
pull_and_build_all() {
    if [[ ! -f "$BUILD_FOLDERS_FILE" ]]; then
        echo -e "${RED}❌ Build configuration file not found: $BUILD_FOLDERS_FILE${NC}"
        echo -e "${YELLOW}Please create build_folders.txt with service paths for build operations${NC}"
        return 1
    fi
    
    echo -e "${WHITE}🔄 Pull and build all services...${NC}"
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
    done < "$BUILD_FOLDERS_FILE"
    
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}📊 Final summary: ${success_count}/${total_count} services processed successfully${NC}"
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
        
        local status=$(get_service_status "$folder")
        echo -e "Status: $status"
        echo ""
        
        echo "1) Start service"
        echo "2) Stop service"
        echo "3) Restart service"
        echo "4) Git pull service"
        echo "5) Clean install service"
        echo "6) Pull and build service"
        echo "7) View logs"
        echo "8) Back to main menu"
        echo ""
        echo -n "Choose an option [1-8]: "
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
                stop_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            3)
                echo ""
                stop_service "$folder"
                sleep 2
                start_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            4)
                echo ""
                git_pull_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            5)
                echo ""
                clean_install_service "$folder"
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            6)
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
            7)
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
            8)
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
                local status=$(get_service_status "$folder")
                
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
        
        echo -e "${WHITE}📋 Main Menu:${NC}"
        echo ""
        echo -e "${CYAN}🎯 Scenario Management:${NC}"
        echo "1) Select run scenario"
        echo ""
        echo -e "${CYAN}🚀 Service Operations:${NC}"
        echo "2) Start all services"
        echo "3) Stop all services"
        echo "4) Restart all services"
        echo "5) Manage individual services"
        echo ""
        echo -e "${CYAN}🔨 Build Operations:${NC}"
        echo "6) Git pull all services"
        echo "7) Clean install all services"
        echo "8) Pull and build all services"
        echo ""
        echo -e "${CYAN}📊 Monitoring:${NC}"
        echo "9) View logs"
        echo "10) View startup statistics"
        echo "11) Refresh status"
        echo "12) Exit"
        echo ""
        echo -n "Choose an option [1-12]: "
        read -r choice
        
        case $choice in
            1)
                select_run_scenario
                ;;
            2)
                echo ""
                start_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            3)
                echo ""
                stop_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            4)
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
            5)
                individual_services_menu
                ;;
            6)
                echo ""
                git_pull_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            7)
                echo ""
                clean_install_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            8)
                echo ""
                pull_and_build_all
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            9)
                show_logs
                ;;
            10)
                show_startup_stats
                ;;
            11)
                # Just refresh by continuing the loop
                ;;
            12)
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

# Check if any run scenario files exist
if [[ $(find "$SCRIPT_DIR" -name "run_*.txt" -type f | wc -l) -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No run scenario files found${NC}"
    echo -e "${CYAN}Please create run_*.txt files from the examples (e.g., run_core.txt, run_all.txt)${NC}"
fi

# Start the main menu
main_menu