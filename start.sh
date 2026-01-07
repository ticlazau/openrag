#!/bin/bash

# OpenRAG Start/Stop Script
# This script manages all OpenRAG services and can be added in the Linux OS startup phase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check if .env file exists
check_env() {
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from .env.example..."
        if [ -f .env.example ]; then
            cp .env.example .env
            print_warning "Please configure .env file with your settings before starting services."
            exit 1
        else
            print_error ".env.example not found. Cannot create .env file."
            exit 1
        fi
    fi
}

# Function to start services
start_services() {
    print_info "Starting OpenRAG services..."

    check_docker
    check_env

    # Start services
    docker-compose up -d

    print_success "Services started successfully!"
    echo ""
    print_info "Waiting for services to be ready (this may take 30-60 seconds)..."
    sleep 15

    # Check service status
    echo ""
    print_info "Service Status:"
    docker-compose ps

    echo ""
    print_success "OpenRAG is ready!"
    echo ""
    echo "Access the services at:"
    echo "  • Frontend:    ${GREEN}http://localhost:3000${NC}"
    echo "  • Backend:     ${GREEN}http://localhost:8000${NC}"
    echo "  • Langflow:    ${GREEN}http://localhost:7860${NC}"
    echo "  • OpenSearch:  ${GREEN}http://localhost:9200${NC}"
    echo "  • Dashboards:  ${GREEN}http://localhost:5601${NC}"
    echo ""
    print_info "To view logs: ${YELLOW}docker-compose logs -f [service-name]${NC}"
    print_info "To stop services: ${YELLOW}./start.sh stop${NC}"
}

# Function to stop services
stop_services() {
    print_info "Stopping OpenRAG services..."

    check_docker

    docker-compose down

    print_success "All services stopped successfully!"
}

# Function to restart services
restart_services() {
    print_info "Restarting OpenRAG services..."

    stop_services
    echo ""
    start_services
}

# Function to show service status
show_status() {
    check_docker

    print_info "OpenRAG Service Status:"
    echo ""
    docker-compose ps

    echo ""
    print_info "Checking service health..."

    # Check if services are responding
    services=(
        "Frontend:http://localhost:3000"
        "Backend:http://localhost:8000/health"
        "Langflow:http://localhost:7860/health"
        "OpenSearch:http://localhost:9200"
    )

    for service in "${services[@]}"; do
        name="${service%%:*}"
        url="${service#*:}"

        if curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -q "200\|302"; then
            print_success "$name is responding"
        else
            print_warning "$name is not responding (may still be starting up)"
        fi
    done
}

# Function to view logs
view_logs() {
    check_docker

    if [ -z "$1" ]; then
        print_info "Showing logs for all services (Ctrl+C to exit)..."
        docker-compose logs -f
    else
        print_info "Showing logs for $1 (Ctrl+C to exit)..."
        docker-compose logs -f "$1"
    fi
}

# Function to clean up (remove containers, volumes, and data)
cleanup() {
    print_warning "This will remove all containers, volumes, and data!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        print_info "Stopping and removing all services..."
        docker-compose down -v

        print_info "Removing OpenSearch data..."
        if [ -d "opensearch-data" ]; then
            rm -rf opensearch-data
            print_success "OpenSearch data removed"
        fi

        print_info "Removing config data..."
        if [ -d "config" ]; then
            rm -rf config
            print_success "Config data removed"
        fi

        print_info "Removing data directory..."
        if [ -d "data" ]; then
            rm -rf data
            print_success "Data directory removed"
        fi

        print_success "Cleanup complete!"
    else
        print_info "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    echo "OpenRAG Management Script"
    echo ""
    echo "Usage: ./start.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start              Start all OpenRAG services"
    echo "  stop               Stop all OpenRAG services"
    echo "  restart            Restart all OpenRAG services"
    echo "  status             Show status of all services"
    echo "  logs [service]     View logs (all services or specific service)"
    echo "  cleanup            Remove all containers, volumes, and data"
    echo "  help               Show this help message"
    echo ""
    echo "Service names for logs:"
    echo "  - openrag-backend"
    echo "  - openrag-frontend"
    echo "  - langflow"
    echo "  - os (OpenSearch)"
    echo "  - osdash (OpenSearch Dashboards)"
    echo ""
    echo "Examples:"
    echo "  ./start.sh start                    # Start all services"
    echo "  ./start.sh logs openrag-backend     # View backend logs"
    echo "  ./start.sh status                   # Check service status"
    echo ""
}

# Main script logic
case "${1:-start}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        view_logs "$2"
        ;;
    cleanup)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
