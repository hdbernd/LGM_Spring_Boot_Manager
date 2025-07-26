#!/usr/bin/env python3
"""
LGM Spring Boot Service Manager - Web UI
A lightweight Flask web interface for the service manager.
"""

import os
import sys
import json
import subprocess
import threading
import time
from datetime import datetime
from flask import Flask, render_template, jsonify, request, Response
import signal

app = Flask(__name__)
app.secret_key = 'lgm-service-manager-2024'

# Configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_MANAGER_SCRIPT = os.path.join(SCRIPT_DIR, 'service_manager.sh')
PID_DIR = os.path.join(SCRIPT_DIR, 'pids')

# Global state
last_status_check = 0
cached_status = {}

def run_bash_command(command, timeout=30):
    """Execute a bash command and return the result."""
    try:
        # Set environment variables for non-interactive mode
        env = os.environ.copy()
        env['TERM'] = 'xterm-256color'
        
        result = subprocess.run(
            ['bash', '-c', command],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=SCRIPT_DIR,
            env=env
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': f'Command timed out after {timeout} seconds',
            'returncode': -1
        }
    except Exception as e:
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
        }

def get_service_status():
    """Get current status of all services."""
    global last_status_check, cached_status
    
    # Cache status for 5 seconds to avoid excessive calls
    current_time = time.time()
    if current_time - last_status_check < 5:
        return cached_status
    
    services = []
    
    # Get current run scenario
    current_scenario = get_current_scenario()
    
    if current_scenario and current_scenario != 'None':
        scenario_file = os.path.join(SCRIPT_DIR, f"run_{current_scenario}.txt")
        if os.path.exists(scenario_file):
            with open(scenario_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        service_name = os.path.basename(line)
                        status = check_single_service_status(line)
                        
                        # Check for JAR availability
                        jar_available = check_jar_availability(line)
                        
                        services.append({
                            'name': service_name,
                            'path': line,
                            'status': status,
                            'jar_available': jar_available
                        })
    
    cached_status = {
        'services': services,
        'scenario': current_scenario,
        'timestamp': datetime.now().isoformat()
    }
    last_status_check = current_time
    
    return cached_status

def check_single_service_status(service_path):
    """Check if a single service is running."""
    service_name = os.path.basename(service_path)
    pid_file = os.path.join(PID_DIR, f"{service_name}.pid")
    
    if os.path.exists(pid_file):
        try:
            with open(pid_file, 'r') as f:
                pid = f.read().strip()
            
            # Check if process is still running
            result = subprocess.run(['ps', '-p', pid], capture_output=True)
            if result.returncode == 0:
                return 'running'
            else:
                # PID file exists but process is dead
                return 'stopped'
        except:
            return 'stopped'
    
    return 'stopped'

def check_jar_availability(service_path):
    """Check if JAR file is available for the service."""
    target_dir = os.path.join(service_path, 'target')
    if os.path.exists(target_dir):
        for file in os.listdir(target_dir):
            if (file.endswith('.jar') and 
                not file.endswith('-sources.jar') and 
                not file.endswith('-javadoc.jar')):
                return True
    return False

def get_current_scenario():
    """Get the current run scenario."""
    default_config = os.path.join(SCRIPT_DIR, '.default_config')
    if os.path.exists(default_config):
        try:
            with open(default_config, 'r') as f:
                for line in f:
                    if line.startswith('DEFAULT_RUN_SCENARIO='):
                        return line.split('=', 1)[1].strip()
        except:
            pass
    return None

def get_available_scenarios():
    """Get list of available run scenarios."""
    scenarios = []
    for file in os.listdir(SCRIPT_DIR):
        if file.startswith('run_') and file.endswith('.txt'):
            scenario_name = file[4:-4]  # Remove 'run_' prefix and '.txt' suffix
            scenarios.append(scenario_name)
    return sorted(scenarios)

@app.route('/')
def index():
    """Main dashboard page."""
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    """API endpoint to get service status."""
    return jsonify(get_service_status())

@app.route('/api/scenarios')
def api_scenarios():
    """API endpoint to get available scenarios."""
    return jsonify({
        'scenarios': get_available_scenarios(),
        'current': get_current_scenario()
    })

@app.route('/api/service/<service_name>/start', methods=['POST'])
def api_start_service(service_name):
    """API endpoint to start a service."""
    data = request.get_json() or {}
    mode = data.get('mode', 'auto')  # auto, jar, maven
    
    # Find service path
    status = get_service_status()
    service_path = None
    for service in status['services']:
        if service['name'] == service_name:
            service_path = service['path']
            break
    
    if not service_path:
        return jsonify({'success': False, 'message': 'Service not found'}), 404
    
    # Start service using the bash script function
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && start_service "{service_path}" "{mode}"'
    result = run_bash_command(command, timeout=60)
    
    # Clear status cache
    global last_status_check
    last_status_check = 0
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/service/<service_name>/stop', methods=['POST'])
def api_stop_service(service_name):
    """API endpoint to stop a service."""
    # Find service path
    status = get_service_status()
    service_path = None
    for service in status['services']:
        if service['name'] == service_name:
            service_path = service['path']
            break
    
    if not service_path:
        return jsonify({'success': False, 'message': 'Service not found'}), 404
    
    # Stop service using the bash script function
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && stop_service "{service_path}"'
    result = run_bash_command(command, timeout=30)
    
    # Clear status cache
    global last_status_check
    last_status_check = 0
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/services/start-all', methods=['POST'])
def api_start_all():
    """API endpoint to start all services."""
    data = request.get_json() or {}
    mode = data.get('mode', 'auto')  # auto, jar, maven
    
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && start_all_services "{mode}"'
    result = run_bash_command(command, timeout=120)
    
    # Clear status cache
    global last_status_check
    last_status_check = 0
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/services/stop-all', methods=['POST'])
def api_stop_all():
    """API endpoint to stop all services."""
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && stop_all_services'
    result = run_bash_command(command, timeout=60)
    
    # Clear status cache
    global last_status_check
    last_status_check = 0
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/build/pull-and-build', methods=['POST'])
def api_pull_and_build():
    """API endpoint to pull and build all services."""
    data = request.get_json() or {}
    parallel = data.get('parallel', True)
    
    if parallel:
        command = f'source "{SERVICE_MANAGER_SCRIPT}" && pull_and_build_all_parallel'
    else:
        command = f'source "{SERVICE_MANAGER_SCRIPT}" && pull_and_build_all'
    
    result = run_bash_command(command, timeout=600)  # 10 minutes timeout
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/logs/<service_name>')
def api_service_logs(service_name):
    """API endpoint to get service logs."""
    log_file = os.path.join(PID_DIR, f"{service_name}.log")
    
    if not os.path.exists(log_file):
        return jsonify({'success': False, 'message': 'Log file not found'}), 404
    
    try:
        # Get last 100 lines
        result = subprocess.run(['tail', '-100', log_file], capture_output=True, text=True)
        return jsonify({
            'success': True,
            'logs': result.stdout,
            'service': service_name
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully."""
    print('\nShutting down web UI...')
    sys.exit(0)

if __name__ == '__main__':
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Check if service manager script exists
    if not os.path.exists(SERVICE_MANAGER_SCRIPT):
        print(f"Error: Service manager script not found at {SERVICE_MANAGER_SCRIPT}")
        sys.exit(1)
    
    print("🌐 LGM Spring Boot Service Manager - Web UI")
    print(f"📂 Working directory: {SCRIPT_DIR}")
    print("🚀 Starting server on http://localhost:8098")
    print("💡 Press Ctrl+C to stop")
    
    app.run(host='0.0.0.0', port=8098, debug=False, threaded=True)