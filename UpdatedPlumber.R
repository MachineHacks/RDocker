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

# Function to generate log file name with a path
generate_log_file_name <- function(stdin_value, log_dir) {
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  timestamp <- format(Sys.time(), "%d%m%y%H%M%S")
  file.path(log_dir, paste0(stdin_value, "_", timestamp, ".txt"))
}

# Function to write request and response to log
write_log <- function(log_file, request, response) {
  cat("Request\n------------------------------------------------------------\n", 
      request, "\n\n", 
      "Response\n------------------------------------------------------------\n", 
      toJSON(response, pretty = TRUE), "\n", 
      file = log_file, append = FALSE)
  cat("Log written to:", log_file, "\n")
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
  
  # Validate JSON structure
  if (!"stdin" %in% names(body_content) || !"files" %in% names(body_content)) {
    return(list(status = "error", output = "Invalid JSON payload: 'stdin' or 'files' missing"))
  }
  
  stdin_value <- body_content$stdin
  files <- body_content$files
  
  # Set the directory path for logs
  log_dir <- "D:/R_Project/log" # Change this to your desired directory
  log_file <- generate_log_file_name(stdin_value, log_dir)
  
  # Process the code from the first file in the JSON
  if (length(files) == 0 || !"content" %in% names(files[[1]])) {
    response <- list(status = "error", output = "No valid code content provided")
    write_log(log_file, req$postBody, response)
    return(response)
  }
  
  code_string <- files[[1]]$content
  
  # Check for restricted commands
  if (!is_code_safe(code_string)) {
    response <- list(status = "error", output = "Code contains restricted commands")
    write_log(log_file, req$postBody, response)
    return(response)
  }
  
  # Execute the code
  result <- execute_code(code_string)
  
  # Write to log file
  write_log(log_file, req$postBody, result)
  
  return(result)
}


# Run the Plumber API with a specific port
# Run this on the terminal: 
# pr <- plumb("your_script_name.R") 
# pr$run(port = 8000)
