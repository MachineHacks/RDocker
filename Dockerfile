# Use the official R base image
FROM rocker/r-ver:4.4.2

# Install system dependencies required by R and packages
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libxt-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libgdal-dev \
    libproj-dev \
    libgeos-dev \
    libudunits2-dev \
    && apt-get clean

# Install required R packages
RUN R -e "install.packages('plumber')"
RUN R -e "install.packages('car')"
RUN R -e "install.packages('dynlm')"
RUN R -e "install.packages('Mfx')"

# Install additional R packages and their dependencies
RUN R -e "install.packages(c('AER', 'cragg', 'moments', 'plm', 'sandwich', 'stargazer', 'tseries', 'urca', 'vars', 'brant', 'erer', 'nnet', 'marginaleffects', 'usmap'), repos='https://cran.r-project.org')"

# Copy your R scripts into the container
COPY plumber_app.R /app/plumber_app.R
COPY Test.R /app/Test.R
COPY Tetsting.R /app/Tetsting.R
COPY main.R /app/main.R
COPY UpdatedPlumber.R /app/UpdatedPlumber.R

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Start the R server with plumber API
ENTRYPOINT ["Rscript", "/app/main.R"]
