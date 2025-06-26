import os
import json
import subprocess
import docker
from flask import Flask, render_template, request, jsonify, flash, redirect, url_for
from datetime import datetime
import psutil
import yaml
from typing import List, Dict, Any

app = Flask(__name__, 
           template_folder='../templates',
           static_folder='../static')
app.secret_key = os.environ.get('SECRET_KEY', 'nexus-docker-manager-secret-key')

# Docker client
docker_client = docker.from_env()

class NexusDockerManager:
    def __init__(self):
        self.compose_project = os.environ.get('COMPOSE_PROJECT_NAME', 'nexus-docker')
        self.compose_dir = '/app/compose'
        
    def get_containers(self) -> List[Dict[str, Any]]:
        """Get all Nexus-related containers"""
        try:
            containers = []
            for container in docker_client.containers.list(all=True):
                if 'nexus' in container.name.lower():
                    containers.append({
                        'id': container.short_id,
                        'name': container.name,
                        'status': container.status,
                        'image': container.image.tags[0] if container.image.tags else 'unknown',
                        'created': container.attrs['Created'],
                        'state': container.attrs['State'],
                        'ports': container.ports,
                        'labels': container.labels,
                        'stats': self.get_container_stats(container.id) if container.status == 'running' else None
                    })
            return containers
        except Exception as e:
            app.logger.error(f"Failed to get containers: {str(e)}")
            return []
    
    def get_container_stats(self, container_id: str) -> Dict[str, Any]:
        """Get real-time stats for a container"""
        try:
            container = docker_client.containers.get(container_id)
            stats = container.stats(stream=False)
            
            # Calculate CPU percentage
            cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - stats['precpu_stats']['cpu_usage']['total_usage']
            system_delta = stats['cpu_stats']['system_cpu_usage'] - stats['precpu_stats']['system_cpu_usage']
            cpu_percent = (cpu_delta / system_delta) * len(stats['cpu_stats']['cpu_usage']['percpu_usage']) * 100 if system_delta > 0 else 0
            
            # Calculate memory usage
            memory_usage = stats['memory_stats']['usage']
            memory_limit = stats['memory_stats']['limit']
            memory_percent = (memory_usage / memory_limit) * 100 if memory_limit > 0 else 0
            
            return {
                'cpu_percent': round(cpu_percent, 2),
                'memory_usage': memory_usage,
                'memory_limit': memory_limit,
                'memory_percent': round(memory_percent, 2),
                'network_rx': stats['networks']['eth0']['rx_bytes'] if 'networks' in stats and 'eth0' in stats['networks'] else 0,
                'network_tx': stats['networks']['eth0']['tx_bytes'] if 'networks' in stats and 'eth0' in stats['networks'] else 0,
            }
        except Exception as e:
            app.logger.error(f"Failed to get container stats: {str(e)}")
            return None
    
    def get_system_metrics(self) -> Dict[str, Any]:
        """Get system-wide metrics"""
        try:
            return {
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory': psutil.virtual_memory()._asdict(),
                'disk': psutil.disk_usage('/')._asdict(),
                'load_avg': os.getloadavg() if hasattr(os, 'getloadavg') else [0, 0, 0],
                'docker_info': docker_client.info()
            }
        except Exception as e:
            app.logger.error(f"Failed to get system metrics: {str(e)}")
            return {}
    
    def container_action(self, container_name: str, action: str) -> Dict[str, Any]:
        """Perform action on container"""
        try:
            container = docker_client.containers.get(container_name)
            
            if action == 'start':
                container.start()
            elif action == 'stop':
                container.stop()
            elif action == 'restart':
                container.restart()
            elif action == 'remove':
                container.remove(force=True)
            else:
                return {'success': False, 'error': 'Invalid action'}
            
            return {'success': True, 'message': f'Container {action} successful'}
        except Exception as e:
            app.logger.error(f"Container action failed: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def get_logs(self, container_name: str, tail: int = 100) -> str:
        """Get container logs"""
        try:
            container = docker_client.containers.get(container_name)
            logs = container.logs(tail=tail, timestamps=True).decode('utf-8')
            return logs
        except Exception as e:
            app.logger.error(f"Failed to get logs: {str(e)}")
            return f"Error getting logs: {str(e)}"
    
    def deploy_service(self, service_type: str, node_ids: str = None) -> Dict[str, Any]:
        """Deploy Nexus services using docker-compose"""
        try:
            if service_type == 'single':
                cmd = ['docker-compose', '-f', f'{self.compose_dir}/docker-compose.yml', 'up', '-d', 'node-1']
            elif service_type == 'multi':
                cmd = ['docker-compose', '-f', f'{self.compose_dir}/docker-compose.yml', '--profile', 'multi', 'up', '-d']
            elif service_type == 'all-single':
                cmd = ['docker-compose', '-f', f'{self.compose_dir}/docker-compose.yml', '--profile', 'multi-single', 'up', '-d']
            else:
                return {'success': False, 'error': 'Invalid service type'}
            
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.compose_dir)
            
            if result.returncode == 0:
                return {'success': True, 'message': f'Successfully deployed {service_type} service', 'output': result.stdout}
            else:
                return {'success': False, 'error': result.stderr}
        except Exception as e:
            app.logger.error(f"Deploy failed: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def stop_all_services(self) -> Dict[str, Any]:
        """Stop all services"""
        try:
            cmd = ['docker-compose', '-f', f'{self.compose_dir}/docker-compose.yml', 'down']
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.compose_dir)
            
            if result.returncode == 0:
                return {'success': True, 'message': 'All services stopped', 'output': result.stdout}
            else:
                return {'success': False, 'error': result.stderr}
        except Exception as e:
            app.logger.error(f"Stop all failed: {str(e)}")
            return {'success': False, 'error': str(e)}

# Initialize manager
nexus_manager = NexusDockerManager()

@app.route('/')
def index():
    """Main dashboard"""
    containers = nexus_manager.get_containers()
    metrics = nexus_manager.get_system_metrics()
    return render_template('dashboard.html', containers=containers, metrics=metrics)

@app.route('/api/containers')
def api_containers():
    """API endpoint for containers"""
    containers = nexus_manager.get_containers()
    return jsonify(containers)

@app.route('/api/metrics')
def api_metrics():
    """API endpoint for system metrics"""
    metrics = nexus_manager.get_system_metrics()
    return jsonify(metrics)

@app.route('/api/container/<container_name>/<action>', methods=['POST'])
def api_container_action(container_name, action):
    """API endpoint for container actions"""
    result = nexus_manager.container_action(container_name, action)
    return jsonify(result)

@app.route('/api/logs/<container_name>')
def api_logs(container_name):
    """API endpoint for container logs"""
    tail = request.args.get('tail', 100, type=int)
    logs = nexus_manager.get_logs(container_name, tail)
    return jsonify({'logs': logs})

@app.route('/api/deploy', methods=['POST'])
def api_deploy():
    """API endpoint for deploying services"""
    data = request.get_json()
    service_type = data.get('type', 'single')
    node_ids = data.get('node_ids')
    
    result = nexus_manager.deploy_service(service_type, node_ids)
    return jsonify(result)

@app.route('/api/stop-all', methods=['POST'])
def api_stop_all():
    """API endpoint for stopping all services"""
    result = nexus_manager.stop_all_services()
    return jsonify(result)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

@app.route('/containers')
def containers_page():
    """Containers management page"""
    containers = nexus_manager.get_containers()
    return render_template('containers.html', containers=containers)

@app.route('/logs')
def logs_page():
    """Logs viewer page"""
    containers = nexus_manager.get_containers()
    return render_template('logs.html', containers=containers)

@app.route('/deploy')
def deploy_page():
    """Deployment page"""
    return render_template('deploy.html')

@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error='Page not found'), 404

@app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error='Internal server error'), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
