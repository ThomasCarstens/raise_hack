#!/bin/bash

# Production Deployment Script for Leonardo's RFQ Alchemy Platform
# This script helps automate the deployment process for both backend and frontend

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Leonardo's RFQ Alchemy"
BACKEND_SERVICE="backend"
FRONTEND_SERVICE="frontend"
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
            print_info "Creating basic .env file..."
            cat > "$ENV_FILE" << EOF
# API Keys
GROQ_API_KEY=your_groq_api_key_here
OPENAI_API_KEY=your_openai_api_key_here

# Frontend API URL
VITE_API_URL=http://localhost:8000

# Database (if using)
POSTGRES_DB=rfq_alchemy
POSTGRES_USER=user
POSTGRES_PASSWORD=password
EOF
            print_warning "Please edit $ENV_FILE with your actual API keys before continuing"
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
    if grep -q "your_groq_api_key_here" "$ENV_FILE" || grep -q "your_openai_api_key_here" "$ENV_FILE"; then
        print_error "Please replace placeholder API keys in $ENV_FILE with actual values"
        exit 1
    fi
    
    print_success "Environment configuration check passed"
}

build_application() {
    print_info "Building application services..."
    
    # Build both services
    if docker-compose build --no-cache; then
        print_success "All services built successfully"
    else
        print_error "Failed to build services"
        exit 1
    fi
}

build_service() {
    local service=$1
    print_info "Building $service service..."
    
    if docker-compose build --no-cache "$service"; then
        print_success "$service service built successfully"
    else
        print_error "Failed to build $service service"
        exit 1
    fi
}

deploy_application() {
    print_info "Deploying application services..."
    
    # Stop existing containers if running
    if docker-compose ps | grep -q "Up"; then
        print_info "Stopping existing containers..."
        docker-compose down
    fi
    
    # Start the application services
    if docker-compose up -d; then
        print_success "All services deployed successfully"
    else
        print_error "Failed to deploy services"
        exit 1
    fi
}

wait_for_health() {
    print_info "Waiting for services to be healthy..."
    
    # Wait for backend
    print_info "Checking backend health..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:8000/docs > /dev/null 2>&1; then
            print_success "Backend is healthy and ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Backend failed to become healthy within expected time"
            print_info "Check backend logs with: docker-compose logs $BACKEND_SERVICE"
            return 1
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    # Wait for frontend
    print_info "Checking frontend health..."
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:5173 > /dev/null 2>&1; then
            print_success "Frontend is healthy and ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Frontend failed to become healthy within expected time"
            print_info "Check frontend logs with: docker-compose logs $FRONTEND_SERVICE"
            return 1
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_success "All services are healthy and ready"
}

show_status() {
    print_info "Application Status:"
    echo ""
    
    # Show container status
    docker-compose ps
    echo ""
    
    # Show resource usage
    print_info "Resource Usage:"
    docker stats --no-stream 2>/dev/null || print_warning "No containers running"
    echo ""
    
    # Show access information
    print_info "Access Information:"
    echo "  🌐 Frontend: http://localhost:5173"
    echo "  🔧 Backend API: http://localhost:8000"
    echo "  📖 API Documentation: http://localhost:8000/docs"
    echo ""
    
    # Show logs command
    print_info "View logs with:"
    echo "  docker-compose logs -f $BACKEND_SERVICE   # Backend logs"
    echo "  docker-compose logs -f $FRONTEND_SERVICE  # Frontend logs"
    echo "  docker-compose logs -f                    # All logs"
}

show_help() {
    echo "Usage: $0 [COMMAND] [SERVICE]"
    echo ""
    echo "Commands:"
    echo "  deploy      - Full deployment (build and start both services)"
    echo "  build       - Build both services or specific service"
    echo "  start       - Start both services or specific service"
    echo "  stop        - Stop both services or specific service"
    echo "  restart     - Restart both services or specific service"
    echo "  status      - Show application status"
    echo "  logs        - Show application logs"
    echo "  health      - Check application health"
    echo "  clean       - Clean up (stop and remove containers/volumes)"
    echo "  help        - Show this help message"
    echo ""
    echo "Services:"
    echo "  backend     - Backend API service"
    echo "  frontend    - Frontend web application"
    echo ""
    echo "Examples:"
    echo "  $0 deploy           # Full deployment of both services"
    echo "  $0 build backend    # Build only backend service"
    echo "  $0 start frontend   # Start only frontend service"
    echo "  $0 logs backend     # View backend logs"
    echo "  $0 status           # Check status of all services"
}

# Main script logic
SERVICE="${2:-}"

case "${1:-deploy}" in
    "deploy")
        print_header
        check_prerequisites
        check_environment
        if [ -n "$SERVICE" ]; then
            build_service "$SERVICE"
            docker-compose up -d "$SERVICE"
        else
            build_application
            deploy_application
        fi
        wait_for_health
        show_status
        ;;
    
    "build")
        print_header
        check_prerequisites
        if [ -n "$SERVICE" ]; then
            build_service "$SERVICE"
        else
            build_application
        fi
        ;;
    
    "start")
        print_header
        check_prerequisites
        check_environment
        if [ -n "$SERVICE" ]; then
            docker-compose up -d "$SERVICE"
        else
            deploy_application
        fi
        wait_for_health
        show_status
        ;;
    
    "stop")
        if [ -n "$SERVICE" ]; then
            print_info "Stopping $SERVICE service..."
            docker-compose stop "$SERVICE"
            print_success "$SERVICE service stopped"
        else
            print_info "Stopping all services..."
            docker-compose down
            print_success "All services stopped"
        fi
        ;;
    
    "restart")
        if [ -n "$SERVICE" ]; then
            print_info "Restarting $SERVICE service..."
            docker-compose restart "$SERVICE"
        else
            print_info "Restarting all services..."
            docker-compose restart
        fi
        wait_for_health
        show_status
        ;;
    
    "status")
        show_status
        ;;
    
    "logs")
        if [ -n "$SERVICE" ]; then
            docker-compose logs -f "$SERVICE"
        else
            docker-compose logs -f
        fi
        ;;
    
    "health")
        backend_healthy=false
        frontend_healthy=false
        
        if curl -f -s http://localhost:8000/docs > /dev/null 2>&1; then
            print_success "Backend is healthy"
            backend_healthy=true
        else
            print_error "Backend is not healthy"
        fi
        
        if curl -f -s http://localhost:5173 > /dev/null 2>&1; then
            print_success "Frontend is healthy"
            frontend_healthy=true
        else
            print_error "Frontend is not healthy"
        fi
        
        if [ "$backend_healthy" = true ] && [ "$frontend_healthy" = true ]; then
            print_success "All services are healthy"
            exit 0
        else
            print_error "Some services are not healthy"
            exit 1
        fi
        ;;
    
    "clean")
        print_warning "This will stop all services and remove all data!"
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