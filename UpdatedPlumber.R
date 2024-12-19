library(plumber)
library(jsonlite)

restricted_commands <- c(
  "install.packages",
  "remove.packages"
)

# Helper function to check for restricted commands
is_code_safe <- function(code_string) {
  for (cmd in restricted_commands) {
    # Check if the restricted command appears in the input code
    if (grepl(cmd, code_string, fixed = TRUE)) {
      return(FALSE) # Code is unsafe if any restricted command is found
    }
  }
  return(TRUE) # Code is safe if no restricted command is found
}

# Simple GET endpoint to check if the API is working
#* @get /ping
function() {
  print("I am alive, use the rconsole execute method to run the R program")
  return(list(message = "I am alive, use the rconsole execute method to run the R program"))
}

# Normalize file path quotes
normalize_quotes <- function(code_string) {
  gsub('read\\.csv\\("([^"]*)"\\)', 'read.csv(\'\\1\')', code_string)
}

# Function to execute R code
execute_code <- function(code_string) {
  tryCatch({
    code_string <- normalize_quotes(code_string)
    code_string <- gsub("\r", "", code_string) # Normalize line endings
    
    cat("Executing the following code:\n", code_string, "\n\n")
    eval_output <- eval(parse(text = code_string))
    cat("\nOutput of the Code Execution:\n")
    print(eval_output)
    
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    cat("\nAn error occurred while executing the code:\n", e$message, "\n")
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Define Plumber API endpoint
#* @post /execute
function(req) {
  # Parse JSON payload
  body_content <- fromJSON(req$postBody, simplifyVector = FALSE)
  
  # Validate the structure of the JSON payload
  if (!"files" %in% names(body_content) || !is.list(body_content$files) || length(body_content$files) == 0) {
    return(list(status = "error", output = "Invalid JSON payload: 'files' array is missing or empty"))
  }
  
  # Process files and execute code
  for (file in body_content$files) {
    if (!is.null(file$name) && grepl("\\.csv$", file$name)) {
      # Handle CSV file
      temp_file <- tempfile(fileext = ".csv")
      writeLines(file$content, temp_file)
      cat("Saved CSV file to:", temp_file, "\n")
    }
  }
  
  # Extract code to execute
  code_string <- body_content$files[[1]]$content
  if (is.null(code_string) || nchar(code_string) == 0) {
    return(list(status = "error", output = "Code content is empty or invalid"))
  }
  
  # Check for restricted commands
  if (!is_code_safe(code_string)) {
    return(list(status = "error", output = "Code contains restricted commands"))
  }
  
  # Execute the code
  result <- execute_code(code_string)
  return(result)
}


# Run the Plumber API with a specific port
# Run this on the terminal: 
# pr <- plumb("your_script_name.R") 
# pr$run(port = 8000)
