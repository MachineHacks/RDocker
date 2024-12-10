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

# Install specific versions of required R packages
RUN Rscript -e "if (!requireNamespace('devtools', quietly = TRUE)) install.packages('devtools', repos = 'https://cran.r-project.org')"

# Install all packages with specific versions
RUN Rscript -e "devtools::install_version('AER', version = '1.2-14', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('car', version = '3.1-3', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('cragg', version = '0.0.1', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('dynlm', version = '0.3-6', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('ggplot2', version = '3.5-1', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('lmtest', version = '0.9-40', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('MASS', version = '7.3-61', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('mfx', version = '1.2-2', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('moments', version = '0.14-1', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('plm', version = '2.6-4', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('sandwich', version = '3.1-1', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('stargazer', version = '5.2-3', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('tseries', version = '0.10-58', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('urca', version = '1.3-4', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('vars', version = '1.6-1', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('brant', version = '0.3-0', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('erer', version = '4.0', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('foreign', version = '0.8-87', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('marginaleffects', version = '0.23-0', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('nnet', version = '7.3-19', repos = 'https://cran.r-project.org')"
RUN Rscript -e "devtools::install_version('usmap', version = '0.7-1', repos = 'https://cran.r-project.org')"

# Copy your R script into the container
COPY plumber_app.R /app/plumber_app.R

# Set the working directory
WORKDIR /app

# Expose the port the API will run on
EXPOSE 8000

# Run the R script using plumber
CMD ["Rscript", "/app/plumber_app.R"]
