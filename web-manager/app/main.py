import os
import json
import subprocess
import shutil
import platform
import signal
import threading
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
import psutil
import yaml

from flask import Flask, render_template, request, jsonify, flash, redirect, url_for, session
from flask_socketio import SocketIO, emit
from werkzeug.security import generate_password_hash, check_password_hash

# Conditional Docker import for standalone mode
try:
    import docker
    from docker.errors import NotFound, APIError
    DOCKER_AVAILABLE = True
except ImportError:
    DOCKER_AVAILABLE = False

app = Flask(__name__, 
           template_folder='../templates',
           static_folder='../static')
app.secret_key = os.environ.get('SECRET_KEY', 'nexus-docker-manager-secret-key')

# WebSocket support for real-time updates
socketio = SocketIO(app, cors_allowed_origins="*")

# Docker client (if available)
docker_client = None
if DOCKER_AVAILABLE:
    try:
        docker_client = docker.from_env()
    except Exception:
        DOCKER_AVAILABLE = False

class NexusManager:
    """Enhanced Nexus CLI Manager supporting multiple deployment modes"""
    
    def __init__(self):
        self.compose_project = os.environ.get('COMPOSE_PROJECT_NAME', 'nexus-docker')
        self.compose_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'compose')
        self.docker_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'docker')
        self.nexus_image = 'nexus-cli:latest'
        self.network_name = 'nexus-network'
        
        # Native process tracking
        self.native_processes = {}
        self.native_process_lock = threading.Lock()
        
        # Determine deployment capabilities
        self.capabilities = self._detect_capabilities()
        
    def _detect_capabilities(self) -> Dict[str, bool]:
        """Detect what deployment modes are available"""
        capabilities = {
            'native': self._check_native_nexus(),
            'docker': DOCKER_AVAILABLE and self._check_docker_access(),
            'compose': self._check_compose_available()
        }
        return capabilities
    
    def _check_native_nexus(self) -> bool:
        """Check if Nexus CLI is available natively on the host"""
        try:
            result = subprocess.run(['nexus', '--version'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def _check_docker_access(self) -> bool:
        """Check if Docker is accessible"""
        if not docker_client:
            return False
        try:
            docker_client.ping()
            return True
        except Exception:
            return False
    
    def _check_compose_available(self) -> bool:
        """Check if Docker Compose is available"""
        try:
            result = subprocess.run(['docker-compose', '--version'], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            try:
                result = subprocess.run(['docker', 'compose', 'version'], 
                                      capture_output=True, text=True, timeout=5)
                return result.returncode == 0
            except (subprocess.TimeoutExpired, FileNotFoundError):
                return False
    
    def get_deployment_modes(self) -> List[Dict[str, Any]]:
        """Get available deployment modes with descriptions"""
        modes = []
        
        if self.capabilities['native']:
            modes.append({
                'id': 'native',
                'name': 'Native Host',
                'description': 'Run Nexus CLI directly on the host system',
                'icon': 'fas fa-desktop',
                'color': 'green',
                'features': ['Direct host access', 'Minimal overhead', 'Easy debugging']
            })
        
        if self.capabilities['docker']:
            modes.append({
                'id': 'docker-single',
                'name': 'Single Docker Container',
                'description': 'One Nexus instance per container',
                'icon': 'fab fa-docker',
                'color': 'blue',
                'features': ['Isolated instances', 'Resource control', 'Easy scaling']
            })
            
            modes.append({
                'id': 'docker-multi',
                'name': 'Multi-Instance Container',
                'description': 'Multiple Nexus instances in one container',
                'icon': 'fas fa-layer-group',
                'color': 'purple',
                'features': ['Resource sharing', 'Centralized logging', 'Efficient deployment']
            })
        
        if self.capabilities['compose']:
            modes.append({
                'id': 'compose',
                'name': 'Docker Compose Stack',
                'description': 'Orchestrated multi-container deployment',
                'icon': 'fas fa-cubes',
                'color': 'orange',
                'features': ['Service orchestration', 'Network isolation', 'Volume management']
            })
        
        return modes
        
    # Native Process Management Methods
    def start_native_instance(self, node_id: str, threads: int = 4, 
                            additional_args: List[str] = None) -> Dict[str, Any]:
        """Start a native Nexus CLI instance on the host"""
        if not self.capabilities['native']:
            return {"success": False, "error": "Native Nexus CLI not available"}
        
        with self.native_process_lock:
            if node_id in self.native_processes:
                return {"success": False, "error": f"Instance {node_id} already running"}
            
            try:
                # Prepare command
                cmd = ['nexus', 'start']
                if threads:
                    cmd.extend(['--threads', str(threads)])
                if additional_args:
                    cmd.extend(additional_args)
                
                # Start process
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )
                
                # Store process info
                self.native_processes[node_id] = {
                    'process': process,
                    'pid': process.pid,
                    'start_time': datetime.now(),
                    'threads': threads,
                    'status': 'running'
                }
                
                return {
                    "success": True,
                    "node_id": node_id,
                    "pid": process.pid,
                    "mode": "native"
                }
                
            except Exception as e:
                return {"success": False, "error": str(e)}
    
    def stop_native_instance(self, node_id: str) -> Dict[str, Any]:
        """Stop a native Nexus CLI instance"""
        with self.native_process_lock:
            if node_id not in self.native_processes:
                return {"success": False, "error": f"Instance {node_id} not found"}
            
            try:
                process_info = self.native_processes[node_id]
                process = process_info['process']
                
                # Graceful shutdown
                if platform.system() == "Windows":
                    process.terminate()
                else:
                    process.send_signal(signal.SIGTERM)
                
                # Wait for graceful shutdown
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                
                del self.native_processes[node_id]
                
                return {"success": True, "node_id": node_id}
                
            except Exception as e:
                return {"success": False, "error": str(e)}
    
    def get_native_instances(self) -> List[Dict[str, Any]]:
        """Get status of all native instances"""
        instances = []
        
        with self.native_process_lock:
            for node_id, info in list(self.native_processes.items()):
                process = info['process']
                
                # Check if process is still running
                if process.poll() is not None:
                    # Process has terminated
                    info['status'] = 'stopped'
                    del self.native_processes[node_id]
                    continue
                
                try:
                    # Get process stats using psutil
                    ps_process = psutil.Process(info['pid'])
                    cpu_percent = ps_process.cpu_percent()
                    memory_info = ps_process.memory_info()
                    
                    instances.append({
                        'node_id': node_id,
                        'mode': 'native',
                        'pid': info['pid'],
                        'status': info['status'],
                        'start_time': info['start_time'].isoformat(),
                        'threads': info['threads'],
                        'cpu_percent': cpu_percent,
                        'memory_mb': memory_info.rss / 1024 / 1024,
                        'uptime': str(datetime.now() - info['start_time'])
                    })
                    
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    # Process no longer exists
                    del self.native_processes[node_id]
        
        return instances

    # Docker Management Methods (Enhanced)
    def ensure_network(self):
        """Ensure the Nexus network exists"""
        if not docker_client:
            return
        try:
            docker_client.networks.get(self.network_name)
        except NotFound:
            docker_client.networks.create(
                self.network_name,
                driver="bridge",
                options={"com.docker.network.bridge.enable_icc": "true"}
            )
    
    def create_single_node_container(self, node_id: str, threads: int = 4, memory_limit: str = "2g", cpu_limit: float = 2.0) -> Dict[str, Any]:
        """Create a single node container"""
        try:
            self.ensure_network()
            
            container_name = f"nexus-node-{node_id}"
            
            # Check if container already exists
            try:
                existing = docker_client.containers.get(container_name)
                if existing.status == 'running':
                    return {"success": False, "error": f"Container {container_name} already running"}
                else:
                    existing.remove(force=True)
            except NotFound:
                pass
            
            # Create volumes
            data_volume = f"nexus_node_{node_id}_data"
            logs_volume = f"nexus_node_{node_id}_logs"
            
            # Create container
            container = docker_client.containers.run(
                image=self.nexus_image,
                name=container_name,
                environment={
                    'NODE_ID': node_id,
                    'MAX_THREADS': str(threads),
                    'NEXUS_ENVIRONMENT': 'production',
                    'CONTAINER_TYPE': 'single'
                },
                volumes={
                    data_volume: {'bind': '/app/data', 'mode': 'rw'},
                    logs_volume: {'bind': '/app/logs', 'mode': 'rw'}
                },
                networks=[self.network_name],
                mem_limit=memory_limit,
                cpu_count=cpu_limit,
                restart_policy={"Name": "unless-stopped"},
                detach=True,
                command="./scripts/start-single.sh"
            )
            
            return {
                "success": True,
                "container_id": container.short_id,
                "container_name": container_name,
                "node_id": node_id
            }
            
        except Exception as e:
            app.logger.error(f"Failed to create single node container: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def create_multi_node_container(self, node_ids: List[str], total_threads: int = 16, memory_limit: str = "4g", cpu_limit: float = 4.0) -> Dict[str, Any]:
        """Create a multi-node container"""
        try:
            self.ensure_network()
            
            container_name = f"nexus-multi-{'-'.join(node_ids[:2])}"  # Use first 2 node IDs for naming
            
            # Check if container already exists
            try:
                existing = docker_client.containers.get(container_name)
                if existing.status == 'running':
                    return {"success": False, "error": f"Container {container_name} already running"}
                else:
                    existing.remove(force=True)
            except NotFound:
                pass
            
            # Create shared volumes
            data_volume = f"nexus_multi_{container_name}_data"
            logs_volume = f"nexus_multi_{container_name}_logs"
            
            # Calculate threads per node
            threads_per_node = max(1, total_threads // len(node_ids))
            
            # Create container
            container = docker_client.containers.run(
                image=self.nexus_image,
                name=container_name,
                environment={
                    'NODE_IDS': ','.join(node_ids),
                    'MAX_THREADS': str(total_threads),
                    'THREADS_PER_NODE': str(threads_per_node),
                    'NEXUS_ENVIRONMENT': 'production',
                    'CONTAINER_TYPE': 'multi'
                },
                volumes={
                    data_volume: {'bind': '/app/data', 'mode': 'rw'},
                    logs_volume: {'bind': '/app/logs', 'mode': 'rw'}
                },
                networks=[self.network_name],
                mem_limit=memory_limit,
                cpu_count=cpu_limit,
                restart_policy={"Name": "unless-stopped"},
                detach=True,
                command="./scripts/start-multi.sh"
            )
            
            return {
                "success": True,
                "container_id": container.short_id,
                "container_name": container_name,
                "node_ids": node_ids,
                "total_threads": total_threads
            }
            
        except Exception as e:
            app.logger.error(f"Failed to create multi-node container: {str(e)}")
            return {"success": False, "error": str(e)}
        
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
    
    def add_new_node(self, node_id: str, node_name: str = None) -> Dict[str, Any]:
        """Add a new single-instance node dynamically"""
        try:
            if not node_name:
                node_name = f"nexus-node-{node_id}"
            
            # Check if container already exists
            try:
                existing = self.docker_client.containers.get(node_name)
                return {'success': False, 'error': f'Container {node_name} already exists'}
            except NotFound:
                pass
            
            # Create container with nexus image
            container = self.docker_client.containers.run(
                image='nexus-cli:latest',
                name=node_name,
                environment={
                    'NODE_ID': node_id,
                    'MAX_THREADS': '4',
                    'NEXUS_ENVIRONMENT': 'production',
                    'DEBUG': 'false'
                },
                volumes={
                    f'nexus_{node_name}_data': {'bind': '/app/data', 'mode': 'rw'},
                    f'nexus_{node_name}_logs': {'bind': '/app/logs', 'mode': 'rw'}
                },
                command=["./scripts/start-single.sh"],
                restart_policy={"Name": "unless-stopped"},
                detach=True,
                labels={'nexus.type': 'single-instance', 'nexus.node-id': node_id}
            )
            
            app.logger.info(f"Created new node container: {node_name} with ID: {node_id}")
            return {'success': True, 'message': f'Node {node_name} created successfully', 'container_id': container.id}
            
        except Exception as e:
            app.logger.error(f"Failed to add new node: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def remove_node(self, container_name: str, remove_volumes: bool = False) -> Dict[str, Any]:
        """Remove a node and optionally its volumes"""
        try:
            container = self.docker_client.containers.get(container_name)
            
            # Stop container if running
            if container.status == 'running':
                container.stop(timeout=30)
            
            # Remove container
            container.remove(force=True)
            
            # Remove volumes if requested
            if remove_volumes:
                try:
                    data_volume = self.docker_client.volumes.get(f'nexus_{container_name}_data')
                    data_volume.remove()
                    logs_volume = self.docker_client.volumes.get(f'nexus_{container_name}_logs')
                    logs_volume.remove()
                except Exception as e:
                    app.logger.warning(f"Failed to remove volumes for {container_name}: {str(e)}")
            
            app.logger.info(f"Removed node container: {container_name}")
            return {'success': True, 'message': f'Node {container_name} removed successfully'}
            
        except NotFound:
            return {'success': False, 'error': f'Container {container_name} not found'}
        except Exception as e:
            app.logger.error(f"Failed to remove node: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def get_available_node_slots(self) -> List[str]:
        """Get list of available node slot names"""
        containers = self.get_containers()
        existing_names = [c['name'] for c in containers if c['name'].startswith('nexus-node-')]
        
        # Generate next available slots
        available_slots = []
        for i in range(1, 21):  # Support up to 20 nodes
            slot_name = f"nexus-node-{i:02d}"
            if slot_name not in existing_names:
                available_slots.append(slot_name)
        
        return available_slots[:5]  # Return first 5 available slots
    
    def scale_nodes(self, target_count: int, node_ids: List[str]) -> Dict[str, Any]:
        """Scale the number of single-instance nodes"""
        try:
            current_containers = [c for c in self.get_containers() 
                                if c['labels'].get('nexus.type') == 'single-instance']
            current_count = len(current_containers)
            
            if target_count == current_count:
                return {'success': True, 'message': f'Already at target count of {target_count} nodes'}
            
            results = []
            
            if target_count > current_count:
                # Scale up - add new nodes
                nodes_to_add = target_count - current_count
                if len(node_ids) < nodes_to_add:
                    return {'success': False, 'error': f'Need {nodes_to_add} node IDs but only {len(node_ids)} provided'}
                
                available_slots = self.get_available_node_slots()
                for i in range(nodes_to_add):
                    if i < len(available_slots) and i < len(node_ids):
                        result = self.add_new_node(node_ids[i], available_slots[i])
                        results.append(result)
            
            elif target_count < current_count:
                # Scale down - remove nodes
                nodes_to_remove = current_count - target_count
                containers_to_remove = current_containers[:nodes_to_remove]
                
                for container in containers_to_remove:
                    result = self.remove_node(container['name'])
                    results.append(result)
            
            success_count = sum(1 for r in results if r['success'])
            return {
                'success': success_count == len(results),
                'message': f'Scaling completed: {success_count}/{len(results)} operations successful',
                'results': results
            }
            
        except Exception as e:
            app.logger.error(f"Scaling failed: {str(e)}")
            return {'success': False, 'error': str(e)}

    # Unified Instance Management
    def get_all_instances(self) -> List[Dict[str, Any]]:
        """Get all instances across all deployment modes"""
        instances = []
        
        # Add native instances
        instances.extend(self.get_native_instances())
        
        # Add Docker container instances
        if DOCKER_AVAILABLE and docker_client:
            try:
                containers = self.get_containers()
                for container in containers:
                    instances.append({
                        'node_id': container.get('labels', {}).get('nexus.node-id', container['name']),
                        'mode': 'docker',
                        'container_id': container['id'],
                        'container_name': container['name'],
                        'status': container['status'],
                        'created': container['created'],
                        'image': container['image'],
                        'stats': container.get('stats'),
                        'ports': container['ports']
                    })
            except Exception as e:
                app.logger.error(f"Failed to get Docker instances: {str(e)}")
        
        return instances
    
    def start_instance(self, mode: str, node_id: str, **kwargs) -> Dict[str, Any]:
        """Start an instance using the specified mode"""
        if mode == 'native':
            return self.start_native_instance(node_id, **kwargs)
        elif mode == 'docker-single':
            return self.create_single_node_container(node_id, **kwargs)
        elif mode == 'docker-multi':
            node_ids = kwargs.get('node_ids', [node_id])
            # Map parameter names for multi-node container
            multi_kwargs = {}
            if 'threads' in kwargs:
                multi_kwargs['total_threads'] = kwargs['threads']
            if 'memory_limit' in kwargs:
                multi_kwargs['memory_limit'] = kwargs['memory_limit']
            if 'cpu_limit' in kwargs:
                multi_kwargs['cpu_limit'] = kwargs['cpu_limit']
            return self.create_multi_node_container(node_ids, **multi_kwargs)
        else:
            return {"success": False, "error": f"Unsupported mode: {mode}"}
    
    def stop_instance(self, mode: str, instance_id: str) -> Dict[str, Any]:
        """Stop an instance"""
        if mode == 'native':
            return self.stop_native_instance(instance_id)
        elif mode.startswith('docker'):
            return self.container_action(instance_id, 'stop')
        else:
            return {"success": False, "error": f"Unsupported mode: {mode}"}
    
    def get_instance_logs(self, mode: str, instance_id: str, tail: int = 100) -> str:
        """Get logs for an instance"""
        if mode == 'native':
            # For native instances, try to read from log files
            return f"Native instance {instance_id} logs (file-based logging not implemented yet)"
        elif mode.startswith('docker'):
            return self.get_logs(instance_id, tail)
        else:
            return f"Unsupported mode: {mode}"
    
    def build_nexus_image(self) -> Dict[str, Any]:
        """Build the Nexus CLI Docker image"""
        if not DOCKER_AVAILABLE:
            return {"success": False, "error": "Docker not available"}
        
        try:
            # Build the image
            image, logs = docker_client.images.build(
                path=self.docker_dir,
                tag=self.nexus_image,
                rm=True,
                pull=True
            )
            
            # Collect build logs
            build_log = ""
            for log in logs:
                if 'stream' in log:
                    build_log += log['stream']
            
            return {
                "success": True,
                "image_id": image.short_id,
                "image_tags": image.tags,
                "build_log": build_log
            }
            
        except Exception as e:
            app.logger.error(f"Failed to build image: {str(e)}")
            return {"success": False, "error": str(e)}

# Initialize manager
nexus_manager = NexusManager()

@app.route('/')
def index():
    """Main dashboard"""
    return render_template('dashboard.html')

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

@app.route('/api/nodes/add', methods=['POST'])
def api_add_node():
    """Add a new node"""
    data = request.get_json()
    node_id = data.get('node_id')
    node_name = data.get('node_name')
    
    if not node_id:
        return jsonify({'success': False, 'error': 'Node ID is required'}), 400
    
    result = nexus_manager.add_new_node(node_id, node_name)
    return jsonify(result)

@app.route('/api/nodes/<container_name>/remove', methods=['DELETE'])
def api_remove_node(container_name):
    """Remove a node"""
    remove_volumes = request.args.get('remove_volumes', 'false').lower() == 'true'
    result = nexus_manager.remove_node(container_name, remove_volumes)
    return jsonify(result)

@app.route('/api/nodes/scale', methods=['POST'])
def api_scale_nodes():
    """Scale nodes to target count"""
    data = request.get_json()
    target_count = data.get('target_count')
    node_ids = data.get('node_ids', [])
    
    if target_count is None:
        return jsonify({'success': False, 'error': 'Target count is required'}), 400
    
    result = nexus_manager.scale_nodes(target_count, node_ids)
    return jsonify(result)

@app.route('/api/nodes/available-slots')
def api_available_slots():
    """Get available node slots"""
    slots = nexus_manager.get_available_node_slots()
    return jsonify({'slots': slots})

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

@app.route('/nodes')
def nodes_page():
    """Node management page"""
    try:
        containers = nexus_manager.get_containers()
        available_slots = nexus_manager.get_available_node_slots()
        return render_template('nodes.html', 
                             containers=containers, 
                             available_slots=available_slots,
                             page_title='Node Management')
    except Exception as e:
        app.logger.error(f"Nodes page error: {str(e)}")
        flash(f'Error loading nodes page: {str(e)}', 'error')
        return redirect(url_for('index'))

@app.route('/create')
def create_instance():
    """Create instance page"""
    return render_template('create.html')

@app.route('/instances')
def instances_page():
    """Instances management page"""
    return render_template('instances.html')

@app.route('/settings')
def settings_page():
    """Settings page"""
    return render_template('settings.html')

@app.route('/favicon.ico')
def favicon():
    """Serve favicon"""
    return '', 204  # No content

@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error='Page not found'), 404

@app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error='Internal server error'), 500

# New API endpoints for dynamic container creation
@app.route('/api/containers/create-single', methods=['POST'])
def api_create_single_container():
    """Create a single node container"""
    data = request.get_json()
    
    # Validate required fields
    node_id = data.get('node_id')
    if not node_id:
        return jsonify({'success': False, 'error': 'Node ID is required'}), 400
    
    # Optional parameters with defaults
    threads = data.get('threads', 4)
    memory_limit = data.get('memory_limit', '2g')
    cpu_limit = data.get('cpu_limit', 2.0)
    
    try:
        result = nexus_manager.create_single_node_container(
            node_id=str(node_id),
            threads=int(threads),
            memory_limit=memory_limit,
            cpu_limit=float(cpu_limit)
        )
        return jsonify(result)
    except ValueError as e:
        return jsonify({'success': False, 'error': f'Invalid parameter: {str(e)}'}), 400
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/containers/create-multi', methods=['POST'])
def api_create_multi_container():
    """Create a multi-node container"""
    data = request.get_json()
    
    # Validate required fields
    node_ids = data.get('node_ids')
    if not node_ids or not isinstance(node_ids, list) or len(node_ids) < 2:
        return jsonify({'success': False, 'error': 'At least 2 node IDs are required for multi-node container'}), 400
    
    # Optional parameters with defaults
    total_threads = data.get('total_threads', 16)
    memory_limit = data.get('memory_limit', '4g')
    cpu_limit = data.get('cpu_limit', 4.0)
    
    try:
        result = nexus_manager.create_multi_node_container(
            node_ids=[str(nid) for nid in node_ids],
            total_threads=int(total_threads),
            memory_limit=memory_limit,
            cpu_limit=float(cpu_limit)
        )
        return jsonify(result)
    except ValueError as e:
        return jsonify({'success': False, 'error': f'Invalid parameter: {str(e)}'}), 400
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/containers/list')
def api_list_containers():
    """Get detailed container information"""
    containers = nexus_manager.get_containers()
    return jsonify({
        'success': True,
        'containers': containers,
        'total': len(containers),
        'running': len([c for c in containers if c['status'] == 'running'])
    })

@app.route('/api/containers/<container_name>/info')
def api_container_info(container_name):
    """Get detailed information about a specific container"""
    try:
        container = docker_client.containers.get(container_name)
        info = {
            'id': container.short_id,
            'name': container.name,
            'status': container.status,
            'image': container.image.tags[0] if container.image.tags else 'unknown',
            'created': container.attrs['Created'],
            'state': container.attrs['State'],
            'config': container.attrs['Config'],
            'network_settings': container.attrs['NetworkSettings'],
            'mounts': container.attrs['Mounts'],
            'logs': nexus_manager.get_logs(container_name, tail=50)
        }
        
        # Add stats if container is running
        if container.status == 'running':
            info['stats'] = nexus_manager.get_container_stats(container.id)
            
        return jsonify({'success': True, 'container': info})
    except NotFound:
        return jsonify({'success': False, 'error': 'Container not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/create')
def create_page():
    """Container creation page"""
    return render_template('create.html')

# API Routes for the new enhanced interface

@app.route('/api/capabilities')
def api_capabilities():
    """Get system capabilities"""
    return jsonify(nexus_manager.capabilities)

@app.route('/api/deployment-modes')
def api_deployment_modes():
    """Get available deployment modes"""
    return jsonify(nexus_manager.get_deployment_modes())

@app.route('/api/instances')
def api_instances():
    """Get all instances"""
    return jsonify(nexus_manager.get_all_instances())

@app.route('/api/instances/<instance_id>/logs')
def api_instance_logs(instance_id):
    """Get logs for a specific instance"""
    mode = request.args.get('mode', 'docker')
    tail = int(request.args.get('tail', 100))
    logs = nexus_manager.get_instance_logs(mode, instance_id, tail)
    return logs, 200, {'Content-Type': 'text/plain'}

@app.route('/api/instances/<instance_id>/start', methods=['POST'])
def api_start_instance(instance_id):
    """Start an instance"""
    data = request.get_json()
    mode = data.get('mode', 'docker')
    
    if mode == 'native':
        result = nexus_manager.start_native_instance(instance_id)
    elif mode.startswith('docker'):
        result = nexus_manager.container_action(instance_id, 'start')
    else:
        result = {"success": False, "error": f"Unsupported mode: {mode}"}
    
    return jsonify(result)

@app.route('/api/instances/<instance_id>/stop', methods=['POST'])
def api_stop_instance(instance_id):
    """Stop an instance"""
    data = request.get_json()
    mode = data.get('mode', 'docker')
    
    result = nexus_manager.stop_instance(mode, instance_id)
    return jsonify(result)

@app.route('/api/instances/<instance_id>/restart', methods=['POST'])
def api_restart_instance(instance_id):
    """Restart an instance"""
    data = request.get_json()
    mode = data.get('mode', 'docker')
    
    # Stop then start
    stop_result = nexus_manager.stop_instance(mode, instance_id)
    if stop_result['success']:
        # Wait a moment
        time.sleep(2)
        start_result = nexus_manager.start_instance(mode, instance_id)
        return jsonify(start_result)
    else:
        return jsonify(stop_result)

@app.route('/api/instances', methods=['POST'])
def api_create_instance():
    """Create a new instance"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"success": False, "error": "No JSON data provided"}), 400
            
        mode = data.get('mode')
        node_id = data.get('node_id')
        
        if not mode or not node_id:
            return jsonify({"success": False, "error": "Mode and node_id are required"}), 400
        
        # Extract additional parameters
        kwargs = {k: v for k, v in data.items() if k not in ['mode', 'node_id']}
        
        result = nexus_manager.start_instance(mode, node_id, **kwargs)
        
        if result.get('success'):
            # Emit socket event for real-time updates
            socketio.emit('instance_created', result)
            return jsonify(result), 201
        else:
            return jsonify(result), 400
            
    except Exception as e:
        app.logger.error(f"Error creating instance: {str(e)}")
        error_response = {"success": False, "error": f"Failed to deploy instance: {str(e)}"}
        return jsonify(error_response), 500

@app.route('/api/system-metrics')
def api_system_metrics():
    """Get current system metrics"""
    metrics = nexus_manager.get_system_metrics()
    
    # Add calculated fields for frontend
    if 'memory' in metrics:
        metrics['memory_percent'] = round((metrics['memory']['used'] / metrics['memory']['total']) * 100, 1)
        metrics['memory_used'] = metrics['memory']['used']
        metrics['memory_total'] = metrics['memory']['total']
    
    return jsonify(metrics)

@app.route('/api/build-image', methods=['POST'])
def api_build_image():
    """Build the Nexus CLI Docker image"""
    result = nexus_manager.build_nexus_image()
    return jsonify(result)

@app.route('/api/health')
def api_health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "capabilities": nexus_manager.capabilities
    })

# WebSocket events for real-time updates
@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    emit('connected', {'message': 'Connected to Nexus Manager'})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    print('Client disconnected')

@socketio.on('request_update')
def handle_request_update():
    """Handle request for data update"""
    try:
        instances = nexus_manager.get_all_instances()
        metrics = nexus_manager.get_system_metrics()
        
        emit('data_update', {
            'instances': instances,
            'metrics': metrics,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        emit('error', {'message': str(e)})

# Background task for periodic updates
def background_thread():
    """Send periodic updates to connected clients"""
    while True:
        socketio.sleep(30)  # Update every 30 seconds
        try:
            instances = nexus_manager.get_all_instances()
            metrics = nexus_manager.get_system_metrics()
            
            socketio.emit('data_update', {
                'instances': instances,
                'metrics': metrics,
                'timestamp': datetime.now().isoformat()
            })
        except Exception as e:
            app.logger.error(f"Background update failed: {str(e)}")

# Start background thread
background_update_thread = threading.Thread(target=background_thread)
background_update_thread.daemon = True
background_update_thread.start()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
