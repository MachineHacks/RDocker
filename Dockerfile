# Use the official R base image
FROM rocker/r-ver:4.4.2

# Install system dependencies required by R and R packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libxt-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libx11-dev \
    libjpeg-dev \
    libpng-dev \
    && apt-get clean

# Update and install the plumber package
RUN Rscript -e "install.packages('plumber', repos = 'https://cran.r-project.org')"

# Copy the R script
COPY plumber_app.R /app/plumber_app.R

# Set working directory
WORKDIR /app

# Expose port 8000
EXPOSE 8000

# Command to run the Plumber server
CMD ["Rscript", "/app/plumber_app.R"]
