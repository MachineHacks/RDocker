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

# Update R's package manager and ensure required dependencies are available
RUN Rscript -e "install.packages('devtools', repos = 'https://cran.r-project.org')"

# Install packages directly without specifying versions
RUN Rscript -e "install.packages(c('AER', 'car', 'cragg', 'dynlm', 'ggplot2', 'lmtest', 'MASS', 'mfx', 'moments', 'plm', 'sandwich', 'stargazer', 'tseries', 'urca', 'vars', 'nnet'), repos = 'https://cran.r-project.org')"

# Copy your R script into the container
COPY plumber_app.R /app/plumber_app.R

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Run the R script using plumber
CMD ["Rscript", "/app/plumber_app.R"]
