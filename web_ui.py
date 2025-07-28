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

def get_build_mode():
    """Get the current build mode."""
    default_config = os.path.join(SCRIPT_DIR, '.default_config')
    if os.path.exists(default_config):
        try:
            with open(default_config, 'r') as f:
                for line in f:
                    if line.startswith('DEFAULT_BUILD_MODE='):
                        return line.split('=', 1)[1].strip()
        except:
            pass
    return 'scenario'  # Default to scenario mode

def get_default_config():
    """Get all default configuration settings."""
    config = {
        'run_scenario': get_current_scenario(),
        'build_mode': get_build_mode()
    }
    return config

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
    scenarios_with_info = []
    available = get_available_scenarios()
    
    for scenario in available:
        scenario_file = os.path.join(SCRIPT_DIR, f"run_{scenario}.txt")
        service_count = 0
        if os.path.exists(scenario_file):
            with open(scenario_file, 'r') as f:
                for line in f:
                    if line.strip() and not line.strip().startswith('#'):
                        service_count += 1
        
        scenarios_with_info.append({
            'name': scenario,
            'service_count': service_count
        })
    
    return jsonify({
        'scenarios': scenarios_with_info,
        'current': get_current_scenario()
    })

@app.route('/api/scenarios/set', methods=['POST'])
def api_set_scenario():
    """API endpoint to set the current scenario."""
    data = request.get_json()
    scenario = data.get('scenario')
    
    if not scenario:
        return jsonify({'success': False, 'message': 'Scenario name required'}), 400
    
    # Validate scenario exists
    available_scenarios = get_available_scenarios()
    if scenario not in available_scenarios:
        return jsonify({'success': False, 'message': 'Invalid scenario'}), 400
    
    # Update default config
    try:
        default_config = os.path.join(SCRIPT_DIR, '.default_config')
        
        # Read existing config
        config_lines = []
        if os.path.exists(default_config):
            with open(default_config, 'r') as f:
                config_lines = f.readlines()
        
        # Update or add scenario line
        scenario_updated = False
        for i, line in enumerate(config_lines):
            if line.startswith('DEFAULT_RUN_SCENARIO='):
                config_lines[i] = f'DEFAULT_RUN_SCENARIO={scenario}\n'
                scenario_updated = True
                break
        
        if not scenario_updated:
            config_lines.append(f'DEFAULT_RUN_SCENARIO={scenario}\n')
        
        # Write back config
        with open(default_config, 'w') as f:
            f.writelines(config_lines)
        
        # Clear status cache
        global last_status_check
        last_status_check = 0
        
        return jsonify({'success': True, 'message': f'Scenario set to {scenario}'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/config')
def api_get_config():
    """API endpoint to get current configuration."""
    return jsonify({
        'success': True,
        'config': get_default_config()
    })

@app.route('/api/config/build-mode', methods=['POST'])
def api_set_build_mode():
    """API endpoint to set build mode."""
    data = request.get_json()
    build_mode = data.get('build_mode')
    
    if build_mode not in ['scenario', 'build_folders']:
        return jsonify({'success': False, 'message': 'Invalid build mode. Must be "scenario" or "build_folders"'}), 400
    
    try:
        default_config = os.path.join(SCRIPT_DIR, '.default_config')
        
        # Read existing config
        config_lines = []
        if os.path.exists(default_config):
            with open(default_config, 'r') as f:
                config_lines = f.readlines()
        
        # Update or add build mode line
        build_mode_updated = False
        for i, line in enumerate(config_lines):
            if line.startswith('DEFAULT_BUILD_MODE='):
                config_lines[i] = f'DEFAULT_BUILD_MODE={build_mode}\n'
                build_mode_updated = True
                break
        
        if not build_mode_updated:
            config_lines.append(f'DEFAULT_BUILD_MODE={build_mode}\n')
        
        # Write back config
        with open(default_config, 'w') as f:
            f.writelines(config_lines)
        
        return jsonify({'success': True, 'message': f'Build mode set to {build_mode}'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/config/clear', methods=['POST'])
def api_clear_config():
    """API endpoint to clear default configuration."""
    try:
        default_config = os.path.join(SCRIPT_DIR, '.default_config')
        
        if os.path.exists(default_config):
            os.remove(default_config)
        
        # Clear status cache
        global last_status_check
        last_status_check = 0
        
        return jsonify({'success': True, 'message': 'Default configuration cleared'})
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

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

@app.route('/api/services/restart-all', methods=['POST'])
def api_restart_all():
    """API endpoint to restart all services."""
    data = request.get_json() or {}
    mode = data.get('mode', 'auto')  # auto, jar, maven
    
    # First stop all services
    stop_command = f'source "{SERVICE_MANAGER_SCRIPT}" && stop_all_services'
    stop_result = run_bash_command(stop_command, timeout=60)
    
    if not stop_result['success']:
        return jsonify({
            'success': False,
            'message': f'Failed to stop services: {stop_result["stderr"]}'
        })
    
    # Wait 3 seconds as in terminal UI
    import time
    time.sleep(3)
    
    # Then start all services
    start_command = f'source "{SERVICE_MANAGER_SCRIPT}" && start_all_services "{mode}"'
    start_result = run_bash_command(start_command, timeout=120)
    
    # Clear status cache
    global last_status_check
    last_status_check = 0
    
    return jsonify({
        'success': start_result['success'],
        'message': f'Restart completed. {start_result["stdout"] if start_result["success"] else start_result["stderr"]}'
    })

@app.route('/api/service/<service_name>/restart', methods=['POST'])
def api_restart_service(service_name):
    """API endpoint to restart a single service."""
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
    
    # First stop the service
    stop_command = f'source "{SERVICE_MANAGER_SCRIPT}" && stop_service "{service_path}"'
    stop_result = run_bash_command(stop_command, timeout=30)
    
    if not stop_result['success']:
        return jsonify({
            'success': False,
            'message': f'Failed to stop {service_name}: {stop_result["stderr"]}'
        })
    
    # Wait 2 seconds
    import time
    time.sleep(2)
    
    # Then start the service
    start_command = f'source "{SERVICE_MANAGER_SCRIPT}" && start_service "{service_path}" "{mode}"'
    start_result = run_bash_command(start_command, timeout=60)
    
    # Clear status cache
    global last_status_check
    last_status_check = 0
    
    return jsonify({
        'success': start_result['success'],
        'message': f'{service_name} restart completed. {start_result["stdout"] if start_result["success"] else start_result["stderr"]}'
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

@app.route('/api/build/git-pull', methods=['POST'])
def api_git_pull_all():
    """API endpoint to git pull all services."""
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && git_pull_all'
    result = run_bash_command(command, timeout=300)  # 5 minutes timeout
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/build/clean-install', methods=['POST'])
def api_clean_install_all():
    """API endpoint to clean install all services."""
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && clean_install_all'
    result = run_bash_command(command, timeout=600)  # 10 minutes timeout
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/build/build-jars', methods=['POST'])
def api_build_jars_only():
    """API endpoint to build JARs only."""
    command = f'source "{SERVICE_MANAGER_SCRIPT}" && build_jars_only'
    result = run_bash_command(command, timeout=300)  # 5 minutes timeout
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/service/<service_name>/git-pull', methods=['POST'])
def api_service_git_pull(service_name):
    """API endpoint to git pull a single service."""
    # Find service path
    status = get_service_status()
    service_path = None
    for service in status['services']:
        if service['name'] == service_name:
            service_path = service['path']
            break
    
    if not service_path:
        return jsonify({'success': False, 'message': 'Service not found'}), 404
    
    # Execute git pull for the service
    command = f'cd "{service_path}" && git pull'
    result = run_bash_command(command, timeout=60)
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/service/<service_name>/clean-install', methods=['POST'])
def api_service_clean_install(service_name):
    """API endpoint to clean install a single service."""
    # Find service path
    status = get_service_status()
    service_path = None
    for service in status['services']:
        if service['name'] == service_name:
            service_path = service['path']
            break
    
    if not service_path:
        return jsonify({'success': False, 'message': 'Service not found'}), 404
    
    # Execute clean install for the service
    command = f'cd "{service_path}" && mvn clean install -DskipTests'
    result = run_bash_command(command, timeout=300)  # 5 minutes timeout
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/service/<service_name>/pull-and-build', methods=['POST'])
def api_service_pull_and_build(service_name):
    """API endpoint to pull and build a single service."""
    # Find service path
    status = get_service_status()
    service_path = None
    for service in status['services']:
        if service['name'] == service_name:
            service_path = service['path']
            break
    
    if not service_path:
        return jsonify({'success': False, 'message': 'Service not found'}), 404
    
    # Execute git pull and clean install for the service
    command = f'cd "{service_path}" && git pull && mvn clean install -DskipTests'
    result = run_bash_command(command, timeout=360)  # 6 minutes timeout
    
    return jsonify({
        'success': result['success'],
        'message': result['stdout'] if result['success'] else result['stderr']
    })

@app.route('/api/analytics/startup-stats')
def api_startup_stats():
    """API endpoint to get startup statistics."""
    try:
        # Read startup statistics from log files
        stats = {}
        startup_stats_file = os.path.join(PID_DIR, 'startup_stats.log')
        
        if os.path.exists(startup_stats_file):
            with open(startup_stats_file, 'r') as f:
                lines = f.readlines()
                
                for line in lines[-50:]:  # Last 50 entries
                    line = line.strip()
                    if ' - ' in line and 'startup time:' in line:
                        parts = line.split(' - ')
                        if len(parts) >= 2:
                            timestamp = parts[0]
                            info = parts[1]
                            
                            if 'startup time:' in info:
                                service_info = info.split('startup time:')
                                service_name = service_info[0].strip()
                                startup_time = service_info[1].strip().replace('s', '')
                                
                                if service_name not in stats:
                                    stats[service_name] = []
                                
                                try:
                                    stats[service_name].append({
                                        'timestamp': timestamp,
                                        'startup_time': float(startup_time)
                                    })
                                except ValueError:
                                    continue
        
        # Calculate averages
        for service in stats:
            times = [entry['startup_time'] for entry in stats[service]]
            stats[service] = {
                'entries': stats[service],
                'average': sum(times) / len(times) if times else 0,
                'min': min(times) if times else 0,
                'max': max(times) if times else 0,
                'count': len(times)
            }
        
        return jsonify({
            'success': True,
            'stats': stats
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/status/thorough')
def api_thorough_status():
    """API endpoint for thorough status checking."""
    try:
        # Execute thorough status check using terminal UI function
        command = f'source "{SERVICE_MANAGER_SCRIPT}" && thorough_status_check'
        result = run_bash_command(command, timeout=30)
        
        return jsonify({
            'success': result['success'],
            'output': result['stdout'],
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/debug/processes')
def api_debug_processes():
    """API endpoint for process debugging information."""
    try:
        debug_info = {}
        
        # Get all Java processes
        java_result = run_bash_command('pgrep -f java', timeout=10)
        if java_result['success']:
            java_pids = java_result['stdout'].strip().split('\n') if java_result['stdout'].strip() else []
            debug_info['java_processes'] = []
            
            for pid in java_pids:
                if pid:
                    ps_result = run_bash_command(f'ps -p {pid} -o pid,ppid,cmd --no-headers', timeout=5)
                    if ps_result['success']:
                        debug_info['java_processes'].append({
                            'pid': pid,
                            'info': ps_result['stdout'].strip()
                        })
        
        # Get all Maven processes
        mvn_result = run_bash_command('pgrep -f mvn', timeout=10)
        if mvn_result['success']:
            mvn_pids = mvn_result['stdout'].strip().split('\n') if mvn_result['stdout'].strip() else []
            debug_info['maven_processes'] = []
            
            for pid in mvn_pids:
                if pid:
                    ps_result = run_bash_command(f'ps -p {pid} -o pid,ppid,cmd --no-headers', timeout=5)
                    if ps_result['success']:
                        debug_info['maven_processes'].append({
                            'pid': pid,
                            'info': ps_result['stdout'].strip()
                        })
        
        # Get Spring Boot processes
        spring_result = run_bash_command('pgrep -f "spring-boot:run"', timeout=10)
        if spring_result['success']:
            spring_pids = spring_result['stdout'].strip().split('\n') if spring_result['stdout'].strip() else []
            debug_info['spring_boot_processes'] = []
            
            for pid in spring_pids:
                if pid:
                    ps_result = run_bash_command(f'ps -p {pid} -o pid,ppid,cmd --no-headers', timeout=5)
                    if ps_result['success']:
                        debug_info['spring_boot_processes'].append({
                            'pid': pid,
                            'info': ps_result['stdout'].strip()
                        })
        
        # Get port usage information
        port_result = run_bash_command('lsof -i -P -n | grep LISTEN | grep java', timeout=10)
        if port_result['success']:
            debug_info['port_usage'] = port_result['stdout'].strip().split('\n') if port_result['stdout'].strip() else []
        else:
            debug_info['port_usage'] = []
        
        return jsonify({
            'success': True,
            'debug_info': debug_info,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/maintenance/cds-ngl-cleanup', methods=['GET'])
def api_cds_ngl_info():
    """API endpoint to get CDS NGL messages file info."""
    try:
        # Execute CDS NGL cleanup info using terminal UI function
        command = f'source "{SERVICE_MANAGER_SCRIPT}" && show_cds_ngl_info'
        result = run_bash_command(command, timeout=10)
        
        return jsonify({
            'success': result['success'],
            'info': result['stdout'],
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/maintenance/cds-ngl-cleanup', methods=['POST'])
def api_cds_ngl_cleanup():
    """API endpoint to perform CDS NGL cleanup."""
    try:
        # Execute CDS NGL cleanup using terminal UI function
        command = f'source "{SERVICE_MANAGER_SCRIPT}" && clean_cds_ngl_messages'
        result = run_bash_command(command, timeout=30)
        
        return jsonify({
            'success': result['success'],
            'message': result['stdout'] if result['success'] else result['stderr']
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/maintenance/system-info')
def api_system_info():
    """API endpoint to get system information."""
    try:
        info = {}
        
        # Get system uptime
        uptime_result = run_bash_command('uptime', timeout=5)
        if uptime_result['success']:
            info['uptime'] = uptime_result['stdout'].strip()
        
        # Get disk usage
        disk_result = run_bash_command('df -h', timeout=5)
        if disk_result['success']:
            info['disk_usage'] = disk_result['stdout'].strip()
        
        # Get memory usage
        memory_result = run_bash_command('free -h', timeout=5)
        if memory_result['success']:
            info['memory_usage'] = memory_result['stdout'].strip()
        
        # Get Java version
        java_result = run_bash_command('java -version', timeout=5)
        if java_result['success']:
            info['java_version'] = java_result['stderr'].strip()  # Java version goes to stderr
        
        # Get Maven version
        mvn_result = run_bash_command('mvn -version', timeout=5)
        if mvn_result['success']:
            info['maven_version'] = mvn_result['stdout'].strip()
        
        return jsonify({
            'success': True,
            'system_info': info,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

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
    
    print("🌐 LGM Spring Boot Service Manager - SAP Fiori Web UI")
    print(f"📂 Working directory: {SCRIPT_DIR}")
    print("🚀 Starting server on http://localhost:8098")
    print("💡 Press Ctrl+C to stop")
    
    # Open browser tab automatically
    import threading
    import webbrowser
    
    def open_browser():
        import time
        time.sleep(1)  # Wait for server to start
        webbrowser.open('http://localhost:8098')
    
    browser_thread = threading.Thread(target=open_browser)
    browser_thread.daemon = True
    browser_thread.start()
    
    app.run(host='0.0.0.0', port=8098, debug=False, threaded=True)