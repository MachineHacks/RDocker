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

# Install required R packages in parallel
RUN R -e "install.packages(c('plumber', 'car', 'dynlm', 'Mfx', 'jsonlite', 'jose', 'digest', 'ini', 'base64enc'), \
                            Ncpus = parallel::detectCores(), repos='https://cran.r-project.org')"

# Install additional R packages in parallel
RUN R -e "install.packages(c('AER', 'cragg', 'moments', 'plm', 'sandwich', 'stargazer', 'tseries', 'urca', 'vars', \
                            'brant', 'erer', 'nnet', 'marginaleffects', 'usmap'), \
                            Ncpus = parallel::detectCores(), repos='https://cran.r-project.org')"

# Copy application files
COPY Plumber.R /app/Plumber.R
COPY main.R /app/main.R
COPY Config.json /app/Config.json
COPY Utility.R /app/Utility.R

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Start the R server with plumber API
ENTRYPOINT ["Rscript", "/app/main.R"]
