library(plumber)

# Simple GET endpoint to check if the API is working
#* @get /test
function() {
  print("The Docker container and Plumber API are working!")
  return(list(message = "The Docker container and Plumber API are working!"))
}

# Function to execute R code from a string
execute_code <- function(code_string) {
  tryCatch({
    cat("Executing the following code:\n")
    cat(code_string, "\n\n")
    eval_output <- eval(parse(text = code_string))
    cat("\nOutput of the Code Execution:\n")
    print(eval_output)
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    cat("\nAn error occurred while executing the code:\n")
    cat(e$message, "\n")
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Function to normalize file path quotes
normalize_quotes <- function(code_string) {
  code_string <- gsub('read\\.csv\\("([^"]*)"\\)', 'read.csv(\'\\1\')', code_string)
  return(code_string)
}

# API endpoint definition
#* @post /execute
function(req) {
  body_content <- req$body
  code_string <- if (is.raw(body_content)) rawToChar(body_content) else body_content
  code_string <- normalize_quotes(code_string)
  if (is.null(code_string) || nchar(code_string) == 0) {
    return(list(status = "error", output = "Decoded code string is empty or invalid"))
  }

  # Initialize the Plumber API
pr <- plumb("/app/plumber_app.R")  # Path to your R script

# Run the Plumber API on port 8000 and allow connections from any host
pr$run(host = "0.0.0.0", port = 8000)
  execute_code(code_string)
}
