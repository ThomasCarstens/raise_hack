# Backend Dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y

# Create non-root user
RUN useradd -m -s /bin/bash vscode
USER vscode

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --user -r requirements.txt

# Install Jupyter kernel
RUN python -m ipykernel install --user --name=python3

# Copy backend source code
COPY --chown=vscode:vscode ./backend ./backend
COPY --chown=vscode:vscode *.py .
COPY --chown=vscode:vscode *.ipynb .
COPY --chown=vscode:vscode *.pdf .
COPY --chown=vscode:vscode *.txt .

# Set environment variables
ENV GROQ_API_KEY=""
ENV OPENAI_API_KEY=""
ENV PYTHONPATH=/app

# Expose port
EXPOSE 8000

# Default command
CMD ["python", "-m", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]