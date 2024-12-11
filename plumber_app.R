library(plumber)

# Simple GET endpoint to check if the API is working
#* @get /test
function() {
  print("The Docker container and Plumber API are working!")
  return(list(message = "The Docker container and Plumber API are working!"))
}



# Run Plumber API
#pr <- plumber::plumb('/app/plumber_app.R') 
#cat("Starting the Plumber API...\n")
#pr$run(host = "0.0.0.0", port = 8000)
