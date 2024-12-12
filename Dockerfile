# Use the official R base image
FROM rocker/r-ver:4.4.2

# Install system dependencies required by R, Python, and other packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libxt-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    python3 \
    python3-pip \
    && apt-get clean

# Install required R packages
RUN R -e "install.packages('plumber')"

# Install Python packages (you can add any additional packages you need)
RUN pip3 install pandas numpy  # Example of Python dependencies

# Copy your R scripts into the container
COPY plumber_app.R /app/plumber_app.R
COPY Test.R /app/Test.R
COPY Tetsting.R /app/Tetsting.R
COPY main.R /app/main.R
COPY plumber_app.R /app/UpdatedPlumber.R
COPY app_raw.py /app/app_raw.py  # Copy Python script into container

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Start the R server with plumber API
# You can also run your Python script here by calling it from R
ENTRYPOINT ["Rscript", "/app/main.R"]
