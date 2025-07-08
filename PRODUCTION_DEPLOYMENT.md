# Production Deployment Guide
## Leonardo's RFQ Alchemy Platform

This guide provides comprehensive instructions for deploying the Leonardo's RFQ Alchemy Platform in a production environment using Docker.

## 📋 Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04+ recommended) or Docker-compatible system
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: Minimum 20GB free space
- **CPU**: 2+ cores recommended
- **Docker**: Version 20.10+ with Docker Compose

### Required API Keys
- **Groq API Key**: For LLM inference ([Get here](https://console.groq.com/keys))
- **OpenAI API Key**: For embeddings ([Get here](https://platform.openai.com/api-keys))

## 🚀 Quick Start Deployment

### 1. Clone and Prepare
```bash
# Clone the repository
git clone <repository-url>
cd langgraph

# Create environment file
cp .env.production.example .env
```

### 2. Configure Environment
Edit the `.env` file with your actual API keys:
```bash
# Required API keys
GROQ_API_KEY=your_actual_groq_api_key_here
OPENAI_API_KEY=your_actual_openai_api_key_here

# Optional: Adjust other settings as needed
DEBUG=False
MAX_FILE_SIZE=10485760
```

### 3. Deploy with Docker Compose
```bash
# Build and start the application
docker-compose up -d

# Check the logs
docker-compose logs -f rfq-alchemy

# Verify health
curl http://localhost:8000/api/health
```

### 4. Access the Application
- **API Base**: http://localhost:8000
- **API Documentation**: http://localhost:8000/api/docs
- **Health Check**: http://localhost:8000/api/health

## 🔧 Advanced Configuration

### Custom Port Configuration
To run on a different port, modify `docker-compose.yml`:
```yaml
ports:
  - "9000:8000"  # External:Internal
```

### Resource Limits
Adjust resource limits in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'      # Increase for better performance
      memory: 8G       # Increase for larger workloads
```

### Persistent Storage
Data is automatically persisted in Docker volumes:
- `rfq_uploads`: Uploaded PDF files
- `rfq_chroma_db`: Vector database
- `rfq_logs`: Application logs

## 🔒 Security Considerations

### 1. API Key Security
- **Never** commit API keys to version control
- Use environment variables or secrets management
- Rotate keys regularly

### 2. Network Security
```bash
# Run behind a reverse proxy (nginx example)
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3. Container Security
- Application runs as non-root user
- Minimal base image used
- Regular security updates recommended

## 📊 Monitoring and Maintenance

### Health Monitoring
```bash
# Check application health
curl -f http://localhost:8000/api/health

# Monitor container resources
docker stats leonardos-rfq-alchemy

# View detailed logs
docker-compose logs --tail=100 -f rfq-alchemy
```

### Log Management
```bash
# View recent logs
docker-compose logs --tail=50 rfq-alchemy

# Follow logs in real-time
docker-compose logs -f rfq-alchemy

# Export logs for analysis
docker-compose logs --no-color rfq-alchemy > app.log
```

### Backup Strategy
```bash
# Backup data volumes
docker run --rm -v rfq_uploads:/data -v $(pwd):/backup alpine tar czf /backup/uploads-backup.tar.gz -C /data .
docker run --rm -v rfq_chroma_db:/data -v $(pwd):/backup alpine tar czf /backup/chroma-backup.tar.gz -C /data .

# Restore from backup
docker run --rm -v rfq_uploads:/data -v $(pwd):/backup alpine tar xzf /backup/uploads-backup.tar.gz -C /data
```

## 🔄 Updates and Maintenance

### Application Updates
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Database Maintenance
```bash
# Clear old data (if needed)
docker-compose down
docker volume rm rfq_uploads rfq_chroma_db
docker-compose up -d
```

## 🐛 Troubleshooting

### Common Issues

#### 1. API Keys Not Working
```bash
# Check environment variables
docker-compose exec rfq-alchemy env | grep API_KEY

# Verify API key format
# Groq keys start with: gsk_
# OpenAI keys start with: sk-
```

#### 2. Port Already in Use
```bash
# Find process using port 8000
sudo lsof -i :8000

# Kill process or change port in docker-compose.yml
```

#### 3. Out of Memory
```bash
# Check memory usage
docker stats leonardos-rfq-alchemy

# Increase memory limits in docker-compose.yml
# Or add swap space to the system
```

#### 4. Storage Issues
```bash
# Check disk space
df -h

# Clean up Docker
docker system prune -a

# Check volume usage
docker system df
```

### Debug Mode
For troubleshooting, enable debug mode:
```bash
# In .env file
DEBUG=True

# Restart container
docker-compose restart rfq-alchemy
```

## 📈 Performance Optimization

### 1. Resource Allocation
- Increase worker processes for high load
- Allocate more memory for large documents
- Use SSD storage for better I/O performance

### 2. Caching
- Consider adding Redis for session caching
- Implement response caching for frequent queries

### 3. Load Balancing
For high availability, run multiple instances:
```yaml
# docker-compose.yml
services:
  rfq-alchemy:
    # ... existing config
    deploy:
      replicas: 3
```

## 🆘 Support and Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Check logs and system resources
2. **Monthly**: Update Docker images and dependencies
3. **Quarterly**: Review and rotate API keys
4. **As needed**: Backup critical data

### Getting Help
- Check application logs first
- Review this deployment guide
- Test with the health check endpoint
- Verify API key configuration

---

## 📝 Production Checklist

Before going live, ensure:

- [ ] API keys are properly configured
- [ ] Environment variables are set correctly
- [ ] Health check endpoint responds successfully
- [ ] Persistent storage is configured
- [ ] Resource limits are appropriate
- [ ] Monitoring is in place
- [ ] Backup strategy is implemented
- [ ] Security measures are applied
- [ ] Documentation is updated

---

*For additional support or questions, refer to the main README.md and SETUP_GUIDE.md files.*
