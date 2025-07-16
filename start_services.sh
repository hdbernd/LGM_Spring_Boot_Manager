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
export MAVEN_OPTS="-Dmaven.compiler.fork=true -Dmaven.compiler.executable=\$JAVAC_PATH"
export JAVA_HOME_FOR_MAVEN="\$JAVA_HOME"

echo "🔧 Using javac at: \$JAVAC_PATH"

# Verify javac exists before proceeding
if [[ ! -f "\$JAVAC_PATH" ]]; then
    echo "❌ Error: javac not found at \$JAVAC_PATH"
    echo "❌ Available Java installations:"
    ls -la /Library/Java/JavaVirtualMachines/
    exit 1
fi

mvn -Djava.home="\$JAVA_HOME" \\
    -Dmaven.compiler.fork=true \\
    -Dmaven.compiler.executable="\$JAVAC_PATH" \\
    -Dmaven.compiler.compilerVersion=21 \\
    spring-boot:run 2>&1 | tee "\$LOG_FILE"
EOF
    chmod +x "$run_script"
    
    # Start in new terminal
    if command -v osascript >/dev/null 2>&1; then
        # macOS - use Terminal.app, starting in the service directory
        osascript -e "tell application \"Terminal\" to do script \"cd '$folder' && $run_script; echo 'Service stopped. You can close this window.'; read -p 'Press Enter to close...'\"" >/dev/null 2>&1 &
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