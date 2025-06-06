# Use a slim Debian base image.
FROM debian:bookworm-slim

# Install necessary packages:
# - bash: For executing your script.
# - curl: Needed to download the gcloud CLI.
# - gnupg: Needed for authenticating the gcloud CLI packages.
# - coreutils: Provides enhanced date command capabilities (e.g., 'date -d').
# - apt-transport-https: Allows APT to retrieve packages over HTTPS.
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    gnupg \
    coreutils \
    apt-transport-https \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud CLI
# Add the gcloud CLI distribution URI to apt sources.
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
# Import the Google Cloud public key.
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
# Update apt and install gcloud CLI.
RUN apt-get update && apt-get install -y google-cloud-cli

# Copy your script into the container.
WORKDIR /app
COPY run.sh .

# Make the script executable.
RUN chmod +x run.sh

# Set the entrypoint to your script. This means when the container runs, it will execute run.sh.
ENTRYPOINT ["/app/run.sh"]