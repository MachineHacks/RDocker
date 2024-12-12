library(plumber)

# Simple GET endpoint to check if the API is working
#* @get /test
function() {
  print("The Docker container and Plumber API are working!")
  return(list(message = "The Docker container and Plumber API are working!"))
}

# Normalize the R code by removing carriage returns, extra spaces, and trimming
normalize_code <- function(code_string) {
  # Remove carriage returns and extra spaces
  code_string <- gsub("\r", "", code_string)  # Remove carriage returns
  code_string <- gsub("\\s+", " ", code_string)  # Replace multiple spaces with a single space
  code_string <- trimws(code_string)  # Trim leading/trailing spaces
  return(code_string)
}

# Function to execute R code from a string
execute_code <- function(code_string) {
  tryCatch({
    # Normalize the code before execution
    code_string <- normalize_code(code_string)
    
    # Print the provided code for debugging purposes
    cat("Executing the following code:\n")
    cat(code_string, "\n\n")
    
    # Execute the R code
    eval_output <- eval(parse(text = code_string))
    
    # Print the output of the execution
    cat("\nOutput of the Code Execution:\n")
    print(eval_output)
    
    # Return the output as a list
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    # Handle errors gracefully
    cat("\nAn error occurred while executing the code:\n")
    cat(e$message, "\n")
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Define Plumber API endpoint for executing R code
#* @post /execute
function(req) {
  # Get the body content of the request
  body_content <- req$body
  
  # Check if the body is raw or text
  if (is.character(body_content)) {
    # If it is not raw, treat it as text
    code_string <- body_content
  } else if (is.raw(body_content)) {
    # If the body is raw, convert it to character
    code_string <- rawToChar(body_content)
  } else {
    # If neither raw nor text, return an error
    return(list(status = "error", output = "The body content is not recognized"))
  }
  
  # Print the raw body content for debugging purposes
  cat("Raw body content:", code_string, "\n")
  
  # Normalize code before execution
  code_string <- normalize_code(code_string)
  
  # Ensure the code string is valid
  if (is.null(code_string) || nchar(code_string) == 0) {
    return(list(status = "error", output = "Decoded code string is empty or invalid"))
  }
  
  # Execute the R code and return the result
  result <- execute_code(code_string)
  
  # Return the result to the client
  return(result)
}

# Run the Plumber API with a specific port
# Run this on the terminal:
# pr <- plumb("your_script_name.R") 
# pr$run(port = 8000)
