# Use the official R base image
FROM rocker/r-ver:4.3.1

# Install system dependencies required by R and packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libxt-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    && apt-get clean
	
# Install required R packages
RUN Rscript -e "install.packages('plumber', repos='https://cran.r-project.org')"

# Copy your R script into the container
COPY plumber_app.R /app/plumber_app.R

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Start the R server with plumber API
CMD ["Rscript", "/app/plumber_app.R"]
