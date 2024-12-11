# Use the official R base image
FROM rocker/r-ver:4.4.2

# Install system dependencies required by R and packages (including devtools dependencies)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libxt-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    git \
    && apt-get clean

# Install devtools first, as Plumber installation depends on it
RUN Rscript -e "install.packages('devtools', repos = 'https://cran.r-project.org')"

# Install Plumber from GitHub using devtools
RUN Rscript -e "devtools::install_github('rstudio/plumber')"

# Install other necessary R packages (optional)
RUN Rscript -e "install.packages(c('AER', 'car', 'cragg', 'dynlm', 'ggplot2', 'lmtest', 'MASS', 'mfx', 'moments', 'plm', 'sandwich', 'stargazer', 'tseries', 'urca', 'vars', 'nnet'), repos = 'https://cran.r-project.org')"

# Copy your R script into the container
COPY plumber_app.R /app/plumber_app.R

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Run the R script using plumber
CMD ["Rscript", "/app/plumber_app.R"]
