library(plumber)
library(jsonlite)

# Restricted commands to be avoided
restricted_commands <- c(
  "install.packages",
  "remove.packages"
)

# Helper function to check for restricted commands
is_code_safe <- function(code_string) {
  for (cmd in restricted_commands) {
    if (grepl(cmd, code_string, fixed = TRUE)) {
      return(FALSE) # Code is unsafe if any restricted command is found
    }
  }
  return(TRUE) # Code is safe if no restricted command is found
}

# Normalize file path quotes for consistency
normalize_quotes <- function(code_string) {
  gsub('read\\.csv\\("([^"]*)"\\)', 'read.csv(\'\\1\')', code_string)
}

# Function to generate log file name based on stdin, files, or timestamp
generate_log_file_name <- function(stdin_value, files, log_dir) {
  # Ensure the log directory exists
  if (!dir.exists(log_dir)) {
    cat("Log directory does not exist. Creating:", log_dir, "\n")
    dir.create(log_dir, recursive = TRUE)
  }
  
  # Generate log file name based on stdin, name in files, or timestamp
  if (!is.null(stdin_value) && stdin_value != "") {
    timestamp <- format(Sys.time(), "%d%m%y%H%M%S")
    log_file_name <- paste0(stdin_value, "_", timestamp, ".txt")
  } else {
    # If stdin is missing, use the "name" field from files or default to "log"
    if ("name" %in% names(files[[1]])) {
      # Extract the file name before the first period (.)
      file_name <- tools::file_path_sans_ext(files[[1]]$name)
    } else {
      file_name <- "log"
    }
    log_file_name <- paste0(file_name, "_", format(Sys.time(), "%d%m%y%H%M%S"), ".txt")
  }
  
  # Construct the log file path
  log_file_path <- file.path(log_dir, log_file_name)
  
  # Try opening the log file
  tryCatch({
    fileConn <- file(log_file_path, open = "w")
    close(fileConn)
    cat("Log file created successfully:", log_file_path, "\n")
  }, error = function(e) {
    cat("Error creating log file:", e$message, "\n")
    stop("Unable to create log file. Please check permissions and file path.")
  })
  
  return(log_file_path)
}

# Function to write request and response to log file
write_log <- function(log_file, request, response) {
  tryCatch({
    cat("Request\n------------------------------------------------------------\n", 
        request, "\n\n", 
        "Response\n------------------------------------------------------------\n", 
        toJSON(response, pretty = TRUE), "\n", 
        file = log_file, append = FALSE)
    cat("Log written to:", log_file, "\n")
  }, error = function(e) {
    cat("Error writing to log file:", e$message, "\n")
  })
}

# Function to execute R code and handle errors
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

# Define the Plumber API endpoint
#* @post /execute
function(req) {
  # Parse JSON payload
  body_content <- fromJSON(req$postBody, simplifyVector = FALSE)
  
  # Validate JSON structure
  if (!("files" %in% names(body_content))) {
    return(list(status = "error", output = "Invalid JSON payload: 'files' missing"))
  }
  
  stdin_value <- if ("stdin" %in% names(body_content)) body_content$stdin else NULL
  files <- body_content$files
  
  # Set the directory path for logs
  log_dir <- "/container/directory/logs" # Change this to your desired directory
  log_file <- generate_log_file_name(stdin_value, files, log_dir)
  
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
