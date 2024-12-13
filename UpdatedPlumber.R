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
    # Normalize line endings by removing \r characters
    code_string <- gsub("\r", "", code_string)

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

# Function to normalize file path quotes (for read.csv)
normalize_quotes <- function(code_string) {
  # Normalize file path quotes (optional, depending on the content)
  code_string <- gsub('read\\.csv\\(\"([^\"]*)\"\)', "read.csv('\\1')", code_string)
  return(code_string)
}

# Define Plumber API endpoint
#* @post /execute
function(req) {
  try {
    # Get the body content of the request
    body_content <- req$postBody

    # Ensure the body is not empty
    if (is.null(body_content) || nchar(body_content) == 0) {
      return(list(status = "error", output = "The request body is empty or invalid"))
    }

    # Normalize the code by removing carriage returns and unnecessary spaces
    code_string <- gsub("\r", "", body_content)
    code_string <- trimws(code_string)

    # Print the raw body content for debugging purposes
    cat("Raw body content:", code_string, "\n")

    # Normalize quotes and line endings if necessary
    code_string <- normalize_quotes(code_string)

    # Execute the R code and return the result
    result <- execute_code(code_string)

    # Return the result to the client
    return(result)
  } catch(e) {
    # Handle unexpected errors
    return(list(status = "error", output = paste("Unexpected error:", e$message)))
  }
}

# To run the Plumber API, save this script as 'your_script_name.R'
# Then run the following commands in your R console:
# library(plumber)
# pr <- plumb("your_script_name.R")
# pr$run(port = 8000)
