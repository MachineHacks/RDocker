library(plumber)

# Simple GET endpoint to check if the API is working
#* @get /test
function() {
  return(list(message = "The Docker container and Plumber API are working!"))
}

# Function to normalize R code by removing comments after the '#' symbol, fixing spacing, and ensuring semicolons
normalize_code <- function(code_string) {
  # Remove the comment portion (everything after #) while preserving the rest of the code
  code_string <- gsub("#.*$", "", code_string)  # Remove comments after #
  
  # Replace multiple spaces with a single space
  code_string <- gsub("\\s+", " ", code_string)
  
  # Trim leading/trailing spaces
  code_string <- trimws(code_string)
  
  # Ensure there's a semicolon at the end of each line (if not a comment line)
  code_string <- gsub("([^;])\n", "\\1;", code_string)  # Add semicolon at the end of each line
  
  # Replace double semicolons (;;) with a single semicolon
  code_string <- gsub(";;", ";", code_string)  # Replace ;; with ;
  
  # Ensure the final semicolon if needed
  code_string <- gsub(";$", "", code_string)  # Remove any trailing semicolons
  code_string <- paste(code_string, ";", sep = "")  # Add one semicolon at the end if not present
  
  # Return the normalized code
  return(code_string)
}

# Function to execute R code from a string
execute_code <- function(code_string) {
  tryCatch({
    # Print the provided code
    cat("Executing the following code:\n")
    cat(code_string, "\n\n")
    
    # Execute the R code
    eval_output <- eval(parse(text = code_string))
    
    # Print the output of the execution
    cat("\nOutput of the Code Execution:\n")
    print(eval_output)
    
    # Return the output
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    # Handle errors gracefully
    cat("\nAn error occurred while executing the code:\n")
    cat(e$message, "\n")
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Function to normalize file path quotes (for read.csv)
normalize_quotes <- function(code_string) {
  # Normalize file path quotes
  code_string <- gsub('read\\.csv\\("([^"]*)"\\)', 'read.csv(\'\\1\')', code_string)
  return(code_string)
}

# Define Plumber API endpoint
#* @post /execute
function(req) {
  # Check if the body is in raw format
  body_content <- req$body
  
  if (is.character(body_content)) {
    # If it is not raw, treat it as text
    code_string <- body_content
  } else if (is.raw(body_content)) {
    # If the body is raw, convert to character
    code_string <- rawToChar(body_content)
  } else {
    # If neither raw nor text, return an error
    return(list(status = "error", output = "The body content is not recognized"))
  }
  
  # Print the raw body for debugging purposes
  cat("Raw body content:", code_string, "\n")
  
  # Normalize quotes if necessary
  code_string <- normalize_quotes(code_string)
  
  # Normalize the code
  code_string <- normalize_code(code_string)
  
  # Ensure the code string is valid
  if (is.null(code_string) || nchar(code_string) == 0) {
    return(list(status = "error", output = "Decoded code string is empty or invalid"))
  }
  
  # Execute the R code and return the result
  result <- execute_code(code_string)
  
  # Return the result
  return(result)
}
