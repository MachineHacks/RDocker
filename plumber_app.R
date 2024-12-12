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
    # Print the provided code for debugging
    cat("Executing the following code:\n")
    cat(code_string, "\n\n")
    
    # Parse and evaluate the R code
    parsed_code <- tryCatch({
      parse(text = code_string)
    }, error = function(e) {
      return(NULL)
    })
    
    # If parsing fails, return an error
    if (is.null(parsed_code)) {
      return(list(status = "error", output = "Failed to parse code"))
    }
    
    # Execute the parsed R code
    eval_output <- tryCatch({
      eval(parsed_code)
    }, error = function(e) {
      return(paste("Error during execution:", e$message))
    })
    
    # Return the output of the execution
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    # Handle errors gracefully
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Function to normalize file path quotes (for read.csv)
normalize_quotes <- function(code_string) {
  # Normalize file path quotes for read.csv
  code_string <- gsub('read\\.csv\\("([^"]*)"\\)', 'read.csv(\'\\1\')', code_string)
  return(code_string)
}

# Define Plumber API endpoint
#* @post /execute
function(req) {
  tryCatch({
    # Check if the body content is in raw format
    body_content <- req$body
    
    # If it's not raw, treat it as text
    if (is.character(body_content)) {
      code_string <- body_content
    } else if (is.raw(body_content)) {
      # If it's raw, convert it to character
      code_string <- rawToChar(body_content)
    } else {
      return(list(status = "error", output = "The body content is not recognized"))
    }
    
    # Print the raw body for debugging purposes
    cat("Raw body content:\n", code_string, "\n")
    
    # Normalize quotes if necessary (for functions like read.csv)
    code_string <- normalize_quotes(code_string)
    
    # Ensure the code string is valid
    if (is.null(code_string) || nchar(code_string) == 0) {
      return(list(status = "error", output = "Decoded code string is empty or invalid"))
    }
    
    # Execute the R code and return the result
    result <- execute_code(code_string)
    
    # Return the result
    return(result)
  }, error = function(e) {
    # Handle and return error responses
    return(list(status = "error", output = paste("Error during request processing:", e$message)))
  })
}

# Run the Plumber API
# pr <- plumb("your_script_name.R")
# pr$run(port = 8000)
