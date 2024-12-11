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

# Expose API port
EXPOSE 8000

# Set entry point to run the Plumber API
ENTRYPOINT ["R", "-e", "pr <- plumber::plumb(rev(commandArgs())[1]); args <- list(host = '0.0.0.0', port = 8000); if (packageVersion('plumber') >= '1.0.0') { pr$setDocs(TRUE) } else { args$swagger <- TRUE }; do.call(pr$run, args)"]

# Copy your custom plumber script
COPY plumber_app.R /app/plumber_app.R
COPY Test.R /app/Test.R
COPY Tetsting.R /app/Tetsting.R

# Set the working directory
WORKDIR /app

# Set default command to run your plumber app
CMD ["/app/plumber_app.R"]

