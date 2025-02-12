# main.R

library(plumber)
library(jsonlite)

# Load utility functions
source("/app/Utility.R")  
config <- load_config("/app/Config.json")  

# Extract API metadata dynamically
api_title <- config$API$TITLE
api_description <- config$API$DESCRIPTION

# Initialize Plumber API
pr <- plumber::plumb("/app/UpdatedPlumber.R")

# Set API Metadata (Title & Description)
pr$setDocs(
  list(
    openapi = "3.0.3",
    info = list(
      title = api_title,
      description = api_description,
      version = "1.0.0"
    )
  )
)

# Run Plumber API
pr$run(port = 8000, host = "0.0.0.0")
