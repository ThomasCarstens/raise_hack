#!/bin/bash

# Production Deployment Script for Leonardo's RFQ Alchemy Platform
# This script helps automate the deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Leonardo's RFQ Alchemy"
CONTAINER_NAME="leonardos-rfq-alchemy"
ENV_FILE=".env"
ENV_EXAMPLE=".env.production.example"

# Functions
print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  $APP_NAME - Production Deployment${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

check_environment() {
    print_info "Checking environment configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Environment file $ENV_FILE not found"
        
        if [ -f "$ENV_EXAMPLE" ]; then
            print_info "Copying example environment file..."
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            print_warning "Please edit $ENV_FILE with your actual API keys before continuing"
            print_info "Required variables: GROQ_API_KEY, OPENAI_API_KEY"
            exit 1
        else
            print_error "No environment file template found"
            exit 1
        fi
    fi
    
    # Check for required environment variables
    if ! grep -q "GROQ_API_KEY=" "$ENV_FILE" || ! grep -q "OPENAI_API_KEY=" "$ENV_FILE"; then
        print_error "Required API keys not found in $ENV_FILE"
        print_info "Please ensure GROQ_API_KEY and OPENAI_API_KEY are set"
        exit 1
    fi
    
    # Check if API keys are not placeholder values
    if grep -q "your_actual_groq_api_key_here" "$ENV_FILE" || grep -q "your_actual_openai_api_key_here" "$ENV_FILE"; then
        print_error "Please replace placeholder API keys in $ENV_FILE with actual values"
        exit 1
    fi
    
    print_success "Environment configuration check passed"
}

build_application() {
    print_info "Building application..."
    
    # Build the Docker image
    if docker-compose build --no-cache; then
        print_success "Application built successfully"
    else
        print_error "Failed to build application"
        exit 1
    fi
}

deploy_application() {
    print_info "Deploying application..."
    
    # Stop existing container if running
    if docker-compose ps | grep -q "$CONTAINER_NAME"; then
        print_info "Stopping existing container..."
        docker-compose down
    fi
    
    # Start the application
    if docker-compose up -d; then
        print_success "Application deployed successfully"
    else
        print_error "Failed to deploy application"
        exit 1
    fi
}

wait_for_health() {
    print_info "Waiting for application to be healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:8000/api/health > /dev/null 2>&1; then
            print_success "Application is healthy and ready"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_error "Application failed to become healthy within expected time"
    print_info "Check logs with: docker-compose logs rfq-alchemy"
    return 1
}

show_status() {
    print_info "Application Status:"
    echo ""
    
    # Show container status
    docker-compose ps
    echo ""
    
    # Show resource usage
    print_info "Resource Usage:"
    docker stats --no-stream "$CONTAINER_NAME" 2>/dev/null || print_warning "Container not running"
    echo ""
    
    # Show access information
    print_info "Access Information:"
    echo "  🌐 API Base URL: http://localhost:8000"
    echo "  📖 API Documentation: http://localhost:8000/api/docs"
    echo "  🏥 Health Check: http://localhost:8000/api/health"
    echo ""
    
    # Show logs command
    print_info "View logs with:"
    echo "  docker-compose logs -f rfq-alchemy"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy    - Full deployment (build and start)"
    echo "  build     - Build the application only"
    echo "  start     - Start the application"
    echo "  stop      - Stop the application"
    echo "  restart   - Restart the application"
    echo "  status    - Show application status"
    echo "  logs      - Show application logs"
    echo "  health    - Check application health"
    echo "  clean     - Clean up (stop and remove containers/volumes)"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy    # Full deployment"
    echo "  $0 status    # Check status"
    echo "  $0 logs      # View logs"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        print_header
        check_prerequisites
        check_environment
        build_application
        deploy_application
        wait_for_health
        show_status
        ;;
    
    "build")
        print_header
        check_prerequisites
        build_application
        ;;
    
    "start")
        print_header
        check_prerequisites
        check_environment
        deploy_application
        wait_for_health
        show_status
        ;;
    
    "stop")
        print_info "Stopping application..."
        docker-compose down
        print_success "Application stopped"
        ;;
    
    "restart")
        print_info "Restarting application..."
        docker-compose restart
        wait_for_health
        show_status
        ;;
    
    "status")
        show_status
        ;;
    
    "logs")
        docker-compose logs -f rfq-alchemy
        ;;
    
    "health")
        if curl -f -s http://localhost:8000/api/health; then
            print_success "Application is healthy"
        else
            print_error "Application is not healthy"
            exit 1
        fi
        ;;
    
    "clean")
        print_warning "This will stop the application and remove all data!"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            docker system prune -f
            print_success "Cleanup completed"
        else
            print_info "Cleanup cancelled"
        fi
        ;;
    
    "help"|"-h"|"--help")
        show_help
        ;;
    
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
