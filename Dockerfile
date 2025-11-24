# Stage 1: Build Dependencies
FROM python:3.11-slim AS builder

WORKDIR /app

# Install dependencies needed for application build (if any)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Final Runtime Image
FROM python:3.11-slim

# Create a non-root user for security 
RUN adduser --system --uid 1000 appuser
WORKDIR /app

# Copy only the necessary installed packages from the builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# Copy application code
COPY . .

# Set non-root user
USER appuser

# Define environment variable for the port
ENV PORT 8000

# Expose the application port
EXPOSE 8000

# Command to run the application (e.g., using Gunicorn for production)
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]