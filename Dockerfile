# Use the official Python image
FROM python:3.12-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Set work directory above app
WORKDIR /app

# Install dependencies
COPY environment.yml .
COPY requirements.txt .  
COPY .env .env
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy application
COPY app ./app

# Copy the .streamlit folder into the container
COPY .streamlit /app/.streamlit

# Expose port
EXPOSE 8000

# Run the Streamlit app
CMD ["streamlit", "run", "app/main.py", "--server.port=8000", "--server.address=0.0.0.0"]
