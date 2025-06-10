# Use a lightweight base image
FROM debian:bookworm-slim

# Install dependencies including ca-certificates and Google Cloud SDK
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    gnupg \
    ca-certificates \
    lsb-release && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update && \
    apt-get install -y google-cloud-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Copy the script
COPY run.sh .

# Make it executable
RUN chmod +x run.sh

# Run the script
ENTRYPOINT ["./run.sh"]
