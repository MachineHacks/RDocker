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
    # Normalize the input: Remove carriage returns, normalize quotes, and trim whitespace
    code_string <- gsub("\r", "", code_string)  # Remove carriage returns
    code_string <- gsub("\\s+$", "", code_string)  # Remove trailing spaces
    code_string <- trimws(code_string)           # Trim overall whitespace
    
    # Print the sanitized code for debugging purposes
    cat("Sanitized R Code for Execution:\n", code_string, "\n\n")
    
    # Evaluate the R code
    eval_output <- eval(parse(text = code_string))
    
    # Return the evaluation output as a string
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    # Return detailed error message
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Function to handle incoming requests and preprocess code
#* @post /execute
function(req) {
  tryCatch({
    # Extract the body content
    raw_body <- req$body
    
    # Convert the raw body to a character string
    if (is.raw(raw_body)) {
      code_string <- rawToChar(raw_body)
    } else {
      stop("Request body is not in raw format.")
    }
    
    # Print the raw code for debugging
    cat("Raw R Code Received:\n", code_string, "\n")
    
    # Normalize the code: Remove carriage returns and extra whitespace
    code_string <- gsub("\r", "", code_string)
    code_string <- trimws(code_string)  # Trim overall whitespace
    
    # Check if the code string is empty
    if (is.null(code_string) || nchar(code_string) == 0) {
      stop("Decoded code string is empty or invalid.")
    }
    
    # Execute the R code and return the result
    result <- execute_code(code_string)
    return(result)
  }, error = function(e) {
    # Handle and return error responses
    return(list(status = "error", output = paste("Error during request processing:", e$message)))
  })
}

# Debugging note
# Run the following to start the server:
# pr <- plumb("your_script_name.R")
# pr$run(port = 8000)
