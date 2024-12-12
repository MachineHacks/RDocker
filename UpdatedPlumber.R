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
    # Convert input to UTF-8 encoding
    code_string <- iconv(code_string, from = "UTF-8", to = "UTF-8")
    
    # Normalize input: Remove carriage returns, trim whitespace, and normalize quotes
    code_string <- gsub("\r", "", code_string)  # Remove carriage returns
    code_string <- trimws(code_string)         # Trim whitespace
    
    # Print the sanitized code for debugging
    cat("Sanitized UTF-8 R Code for Execution:\n", code_string, "\n\n")
    
    # Try to parse the code
    parsed_code <- tryCatch({
      parse(text = code_string)
    }, error = function(e) {
      return(NULL)
    })
    
    # If parsing fails, return an error
    if (is.null(parsed_code)) {
      return(list(status = "error", output = "Failed to parse code."))
    }
    
    # Execute the parsed R code
    eval_output <- tryCatch({
      eval(parsed_code)
    }, error = function(e) {
      return(paste("Error during execution:", e$message))
    })
    
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
    # Extract the raw body content
    raw_body <- req$rook$input$read()  # Use rook's input to get raw data
    
    # Check if the raw_body is empty or invalid
    if (length(raw_body) == 0) {
      stop("Request body is empty.")
    }
    
    # Convert the raw body to a UTF-8 character string
    code_string <- rawToChar(raw_body)
    
    # Ensure the input is UTF-8 encoded
    code_string <- iconv(code_string, from = "UTF-8", to = "UTF-8")
    
    # Print the raw code for debugging
    cat("Raw UTF-8 R Code Received:\n", code_string, "\n")
    
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
