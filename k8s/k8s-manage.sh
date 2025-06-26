#!/bin/bash

# Kubernetes deployment script for Nexus CLI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        return 1
    fi
    return 0
}

check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    return 0
}

deploy() {
    log_info "Deploying Nexus CLI to Kubernetes..."
    
    check_kubectl || exit 1
    check_cluster || exit 1
    
    # Apply configurations in order
    log_info "Creating namespace..."
    kubectl apply -f "$K8S_DIR/service.yaml"
    
    log_info "Creating ConfigMaps and PVCs..."
    kubectl apply -f "$K8S_DIR/configmap.yaml"
    
    log_info "Creating deployments..."
    kubectl apply -f "$K8S_DIR/deployment.yaml"
    
    log_info "Deployment completed!"
    
    # Wait for pods to be ready
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=nexus-cli -n nexus --timeout=300s
    
    show_status
}

undeploy() {
    log_warn "This will remove all Nexus CLI resources from Kubernetes. Continue? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        log_info "Removing Nexus CLI from Kubernetes..."
        
        kubectl delete -f "$K8S_DIR/deployment.yaml" 2>/dev/null || true
        kubectl delete -f "$K8S_DIR/configmap.yaml" 2>/dev/null || true
        kubectl delete -f "$K8S_DIR/service.yaml" 2>/dev/null || true
        
        log_info "Undeploy completed!"
    else
        log_info "Undeploy cancelled."
    fi
}

show_status() {
    check_kubectl || exit 1
    
    log_info "Nexus CLI Status in Kubernetes:"
    echo ""
    
    echo "Pods:"
    kubectl get pods -n nexus -l app=nexus-cli -o wide
    echo ""
    
    echo "Services:"
    kubectl get svc -n nexus -l app=nexus-cli
    echo ""
    
    echo "PersistentVolumeClaims:"
    kubectl get pvc -n nexus
    echo ""
    
    echo "ConfigMaps:"
    kubectl get cm -n nexus -l app=nexus-cli
}

show_logs() {
    local deployment="$1"
    local follow="${2:-false}"
    
    check_kubectl || exit 1
    
    if [ -n "$deployment" ]; then
        log_info "Showing logs for $deployment..."
        if [ "$follow" = "true" ]; then
            kubectl logs -f -n nexus deployment/"$deployment"
        else
            kubectl logs -n nexus deployment/"$deployment" --tail=100
        fi
    else
        log_info "Available deployments:"
        kubectl get deployments -n nexus -l app=nexus-cli
        echo ""
        log_info "Use: $0 logs <deployment-name>"
    fi
}

scale() {
    local deployment="$1"
    local replicas="$2"
    
    if [ -z "$deployment" ] || [ -z "$replicas" ]; then
        log_error "Usage: $0 scale <deployment> <replicas>"
        return 1
    fi
    
    check_kubectl || exit 1
    
    log_info "Scaling $deployment to $replicas replicas..."
    kubectl scale deployment "$deployment" -n nexus --replicas="$replicas"
    
    log_info "Waiting for scaling to complete..."
    kubectl rollout status deployment/"$deployment" -n nexus
}

restart() {
    local deployment="$1"
    
    check_kubectl || exit 1
    
    if [ -n "$deployment" ]; then
        log_info "Restarting deployment: $deployment"
        kubectl rollout restart deployment/"$deployment" -n nexus
        kubectl rollout status deployment/"$deployment" -n nexus
    else
        log_info "Restarting all Nexus CLI deployments..."
        kubectl rollout restart deployment -n nexus -l app=nexus-cli
        kubectl rollout status deployment -n nexus -l app=nexus-cli
    fi
}

update_config() {
    log_info "Updating configuration..."
    
    check_kubectl || exit 1
    
    kubectl apply -f "$K8S_DIR/configmap.yaml"
    
    log_info "Configuration updated. Restart deployments to apply changes:"
    log_info "  $0 restart nexus-single-node"
    log_info "  $0 restart nexus-multi-node"
}

describe() {
    local resource_type="$1"
    local resource_name="$2"
    
    check_kubectl || exit 1
    
    if [ -z "$resource_type" ]; then
        log_info "Available resources:"
        kubectl api-resources --namespaced=true | grep -E "pods|deployments|services|configmaps|persistentvolumeclaims"
        return 0
    fi
    
    if [ -n "$resource_name" ]; then
        kubectl describe "$resource_type" "$resource_name" -n nexus
    else
        kubectl describe "$resource_type" -n nexus -l app=nexus-cli
    fi
}

exec_pod() {
    local deployment="$1"
    local command="${2:-/bin/bash}"
    
    if [ -z "$deployment" ]; then
        log_error "Usage: $0 exec <deployment> [command]"
        return 1
    fi
    
    check_kubectl || exit 1
    
    local pod
    pod=$(kubectl get pod -n nexus -l app=nexus-cli -l type="$deployment" -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod" ]; then
        log_error "No pod found for deployment: $deployment"
        return 1
    fi
    
    log_info "Executing command in pod: $pod"
    kubectl exec -it -n nexus "$pod" -- "$command"
}

port_forward() {
    local service="$1"
    local port="${2:-8080}"
    
    if [ -z "$service" ]; then
        log_error "Usage: $0 port-forward <service> [local-port]"
        return 1
    fi
    
    check_kubectl || exit 1
    
    log_info "Port forwarding service $service to localhost:$port"
    log_info "Press Ctrl+C to stop port forwarding"
    kubectl port-forward -n nexus service/"$service" "$port":8080
}

show_help() {
    cat << 'EOF'
Nexus CLI Kubernetes Management Script

Usage: ./k8s-manage.sh <command> [options]

DEPLOYMENT COMMANDS:
  deploy               Deploy Nexus CLI to Kubernetes
  undeploy             Remove all Nexus CLI resources
  update-config        Update ConfigMaps and restart deployments

STATUS COMMANDS:
  status               Show status of all resources
  logs <deployment>    Show logs for deployment
  logs-follow <dep>    Follow logs for deployment
  describe <type> [name] Describe Kubernetes resources

SCALING COMMANDS:
  scale <dep> <count>  Scale deployment to specific replica count
  restart [deployment] Restart deployment(s)

UTILITY COMMANDS:
  exec <dep> [cmd]     Execute command in pod
  port-forward <svc> [port] Forward service port to localhost

EXAMPLES:
  ./k8s-manage.sh deploy
  ./k8s-manage.sh status
  ./k8s-manage.sh logs nexus-single-node
  ./k8s-manage.sh logs-follow nexus-multi-node
  ./k8s-manage.sh scale nexus-single-node 5
  ./k8s-manage.sh exec single-instance /bin/bash
  ./k8s-manage.sh port-forward nexus-single-service 8080

DEPLOYMENTS:
  nexus-single-node    Single instance deployment
  nexus-multi-node     Multi-instance deployment

SERVICES:
  nexus-single-service Service for single instances
  nexus-multi-service  Service for multi instances

EOF
}

case "${1:-help}" in
    deploy)
        deploy
        ;;
    undeploy)
        undeploy
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    logs-follow)
        show_logs "$2" "true"
        ;;
    scale)
        scale "$2" "$3"
        ;;
    restart)
        restart "$2"
        ;;
    update-config)
        update_config
        ;;
    describe)
        describe "$2" "$3"
        ;;
    exec)
        exec_pod "$2" "$3"
        ;;
    port-forward)
        port_forward "$2" "$3"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
