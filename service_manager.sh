#!/bin/bash

# Spring Boot Service Manager - Interactive Terminal UI
# Manages Spring Boot services with a simple menu interface

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOLDERS_FILE="$SCRIPT_DIR/folders.txt"
PID_DIR="$SCRIPT_DIR/pids"

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

# Function to show service status
show_status() {
    echo -e "${WHITE}📊 Service Status:${NC}"
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
    done < "$FOLDERS_FILE"
    
    echo ""
    echo -e "${CYAN}Summary: ${running_count}/${total_count} services running${NC}"
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
    echo -e "${WHITE}🚀 Starting all services...${NC}"
    echo ""
    
    while IFS= read -r folder || [[ -n "$folder" ]]; do
        if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
            start_service "$folder"
        fi
    done < "$FOLDERS_FILE"
    
    echo ""
    echo -e "${GREEN}🎉 All services started!${NC}"
}

# Function to stop all services
stop_all_services() {
    echo -e "${WHITE}🛑 Stopping all services...${NC}"
    echo ""
    
    for pid_file in "$PID_DIR"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local service_name=$(basename "$pid_file" .pid)
            
            # Find folder for this service
            while IFS= read -r folder || [[ -n "$folder" ]]; do
                if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
                    if [[ "$(basename "$folder")" == "$service_name" ]]; then
                        stop_service "$folder"
                        break
                    fi
                fi
            done < "$FOLDERS_FILE"
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
    echo -e "${WHITE}📥 Git pulling all services...${NC}"
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
    done < "$FOLDERS_FILE"
    
    echo -e "${CYAN}📊 Git pull summary: ${success_count}/${total_count} services updated successfully${NC}"
}

# Function to clean install all services
clean_install_all_services() {
    echo -e "${WHITE}🔨 Clean installing all services...${NC}"
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
    done < "$FOLDERS_FILE"
    
    echo -e "${CYAN}📊 Clean install summary: ${success_count}/${total_count} services built successfully${NC}"
}

# Function to pull and build all services (like original script)
pull_and_build_all() {
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
    done < "$FOLDERS_FILE"
    
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}📊 Final summary: ${success_count}/${total_count} services processed successfully${NC}"
    echo -e "${PURPLE}========================================${NC}"
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
    while true; do
        show_header
        echo -e "${WHITE}🔧 Individual Service Management${NC}"
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
        done < "$FOLDERS_FILE"
        
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
        echo -e "${CYAN}🚀 Service Operations:${NC}"
        echo "1) Start all services"
        echo "2) Stop all services"
        echo "3) Restart all services"
        echo "4) Manage individual services"
        echo ""
        echo -e "${CYAN}🔨 Build Operations:${NC}"
        echo "5) Git pull all services"
        echo "6) Clean install all services"
        echo "7) Pull and build all services"
        echo ""
        echo -e "${CYAN}📊 Monitoring:${NC}"
        echo "8) View logs"
        echo "9) Refresh status"
        echo "10) Exit"
        echo ""
        echo -n "Choose an option [1-10]: "
        read -r choice
        
        case $choice in
            1)
                echo ""
                start_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                echo ""
                stop_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            3)
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
            4)
                individual_services_menu
                ;;
            5)
                echo ""
                git_pull_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            6)
                echo ""
                clean_install_all_services
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            7)
                echo ""
                pull_and_build_all
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            8)
                show_logs
                ;;
            9)
                # Just refresh by continuing the loop
                ;;
            10)
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

# Check if folders.txt exists
if [[ ! -f "$FOLDERS_FILE" ]]; then
    echo -e "${RED}❌ Error: folders.txt not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Start the main menu
main_menu