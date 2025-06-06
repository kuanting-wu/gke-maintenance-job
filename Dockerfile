# Use a slim Debian base image.
FROM debian:bookworm-slim

# Install necessary packages:
# - bash: For executing your script.
# - coreutils: Provides enhanced date command capabilities (e.g., 'date -d').
# **注意：這裡移除了安裝 gcloud CLI 的步驟，因為 Cloud Run 會提供。**
RUN apt-get update && apt-get install -y \
    bash \
    coreutils \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Copy your script into the container.
WORKDIR /app
COPY run.sh .

# Make the script executable.
RUN chmod +x run.sh

# Set the entrypoint to your script. This means when the container runs, it will execute run.sh.
ENTRYPOINT ["/app/run.sh"]