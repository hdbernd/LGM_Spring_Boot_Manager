#!/bin/bash

# Spring Boot Services Starter
# This script starts all Spring Boot services defined in folders.txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOLDERS_FILE="$SCRIPT_DIR/folders.txt"
PID_DIR="$SCRIPT_DIR/pids"

# Create PID directory if it doesn't exist
mkdir -p "$PID_DIR"

echo "🚀 Starting Spring Boot services..."

# Check if folders.txt exists
if [[ ! -f "$FOLDERS_FILE" ]]; then
    echo "❌ Error: folders.txt not found in $SCRIPT_DIR"
    exit 1
fi

# Function to start a service
start_service() {
    local folder="$1"
    local service_name=$(basename "$folder")
    
    if [[ ! -d "$folder" ]]; then
        echo "⚠️  Warning: Directory $folder does not exist, skipping..."
        return
    fi
    
    if [[ ! -f "$folder/pom.xml" ]]; then
        echo "⚠️  Warning: No pom.xml found in $folder, skipping..."
        return
    fi
    
    echo "🔄 Starting $service_name..."
    
    cd "$folder"
    
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
    
    # Start in new terminal
    if command -v osascript >/dev/null 2>&1; then
        # macOS - use Terminal.app
        osascript -e "tell application \"Terminal\" to do script \"$run_script; echo 'Service stopped. You can close this window.'; read -p 'Press Enter to close...'\"" >/dev/null 2>&1 &
        local terminal_pid=$!
        
        # Wait a moment and try to find the mvn process
        sleep 3
        local mvn_pid=$(pgrep -f "mvn spring-boot:run.*$service_name" | head -1)
        if [[ -n "$mvn_pid" ]]; then
            echo $mvn_pid > "$PID_DIR/$service_name.pid"
            echo "✅ Started $service_name in terminal (PID: $mvn_pid)"
        else
            echo $terminal_pid > "$PID_DIR/$service_name.pid"
            echo "✅ Started $service_name terminal (waiting for startup...)"
        fi
    else
        echo "⚠️  Terminal opening not supported on this system"
        echo "   Run manually: cd $folder && mvn spring-boot:run"
    fi
}

# Read folders from folders.txt and start services
while IFS= read -r folder || [[ -n "$folder" ]]; do
    # Skip empty lines and comments
    if [[ -n "$folder" && ! "$folder" =~ ^[[:space:]]*# ]]; then
        start_service "$folder"
    fi
done < "$FOLDERS_FILE"

echo ""
echo "🎉 All services started!"
echo "📋 Use './stop_services.sh' to stop all services"
echo "📊 Monitor logs in the 'pids' directory"