# Production Dockerfile for Leonardo's RFQ Alchemy Platform
# Based on devcontainer configuration with production optimizations

# ============================================================================
# Stage 1: Frontend Build Stage
# ============================================================================
FROM node:18-alpine AS frontend-builder

# Set working directory for frontend build
WORKDIR /app/frontend

# Copy frontend package files
COPY leonardos-rfq-alchemy-main/package*.json ./

# Install frontend dependencies
# RUN npm ci --only=production --silent
# RUN npm ci --silent
RUN npm install

# Copy frontend source code
COPY leonardos-rfq-alchemy-main/ ./

# Build frontend for production
RUN npm run build

# ============================================================================
# Stage 2: Python Dependencies Stage
# ============================================================================
FROM python:3.11-slim AS python-deps

# Install system dependencies required for Python packages
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Create virtual environment and install Python dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ============================================================================
# Stage 3: Production Runtime Stage
# ============================================================================
FROM python:3.11-slim AS production

# Install runtime system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy Python virtual environment from deps stage
COPY --from=python-deps /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy built frontend from frontend-builder stage
COPY --from=frontend-builder /app/frontend/dist ./static

# Copy backend application code
COPY backend/ ./backend/

# Copy only essential startup files (not development scripts)
# start_backend.py is for development - production uses gunicorn directly

# Create necessary directories with proper permissions
RUN mkdir -p /app/data/uploads /app/data/chroma_proposal_db && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# ============================================================================
# Production Configuration
# ============================================================================

# Environment variables for production
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Production-specific environment variables
# Note: These should be overridden at runtime with actual values
ENV DEBUG=False
ENV CHROMA_PERSIST_DIRECTORY=/app/data/chroma_proposal_db
ENV UPLOAD_DIRECTORY=/app/data/uploads

# API Keys - MUST be provided at runtime via environment variables
# ENV GROQ_API_KEY=your_groq_api_key_here
# ENV OPENAI_API_KEY=your_openai_api_key_here

# Expose the application port
EXPOSE 8000

# Health check to ensure the application is running
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# ============================================================================
# Production Startup Command
# ============================================================================

# Use gunicorn for production WSGI server with uvicorn workers
# This provides better performance and stability than uvicorn alone
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--worker-connections", "1000", \
     "--max-requests", "1000", \
     "--max-requests-jitter", "100", \
     "--timeout", "120", \
     "--keepalive", "5", \
     "--log-level", "info", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "backend.main:app"]

# ============================================================================
# Usage Instructions
# ============================================================================
#
# To build the image:
#   docker build -t leonardos-rfq-alchemy .
#
# To run the container:
#   docker run -d \
#     --name rfq-alchemy \
#     -p 8000:8000 \
#     -e GROQ_API_KEY=your_actual_groq_key \
#     -e OPENAI_API_KEY=your_actual_openai_key \
#     -v /host/data:/app/data \
#     leonardos-rfq-alchemy
#
# For development/testing without persistent storage:
#   docker run -d \
#     --name rfq-alchemy-dev \
#     -p 8000:8000 \
#     -e GROQ_API_KEY=your_actual_groq_key \
#     -e OPENAI_API_KEY=your_actual_openai_key \
#     leonardos-rfq-alchemy
#
# ============================================================================
