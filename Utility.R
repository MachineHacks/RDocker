# utility.R - Helper and Validation Functions

library(jsonlite)
library(jose)
library(digest)
library(openssl)
library(base64enc)


# Restricted commands to be avoided
#restricted_commands <- c( "install.packages","remove.packages","system", "unlink", "sink", "rm -rf", "echo")

# Restricted commands to be avoided (including package manipulation and library path changes)
restricted_commands <- c(
  "install.packages",  # Installing packages
  "remove.packages",   # Removing packages
  "system",             # System-level commands
  "unlink",             # File removal
  "sink",               # Redirect output
  "rm -rf",             # Deleting files or directories
  "echo",               # Printing to shell
  ".libPaths",          # Redirecting library paths
  "setwd",               # Changing working directory (if needed)
  "dyn.load",           # Dynamically load shared libraries (can be used for loading potentially dangerous code)
  ".Call",              # Calling compiled C code (may allow execution of low-level, potentially harmful code)
  "readLines\\('/etc/passwd'",  # Prevent reading system files like /etc/passwd
  "writeLines\\('.*/tmp/.*\\.sh'", # Prevent writing malicious scripts to /tmp
)


# Function to check if the code is safe
is_code_safe <- function(code_string) {
  for (cmd in restricted_commands) {
    if (grepl(cmd, code_string, fixed = TRUE)) {
      return(FALSE)
    }
  }
  return(TRUE)
}

# Normalize file path quotes
normalize_quotes <- function(code_string) {
  gsub('read\\.csv\\("([^"]*)"\\)', 'read.csv(\'\\1\')', code_string)
}

# Load user credentials from a JSON config file
load_config <- function(config_path) {
  tryCatch({
    config <- fromJSON(config_path)
    return(config)
  }, error = function(e) {
    cat(Sys.time(), "[ERROR] Failed to load configuration -", e$message, "\n", file=stderr())
    return(NULL)
  })
}

authenticate_user <- function(CLIENT_ID, PASSWORD, config) {
  tryCatch({
    credentials_df <- as.data.frame(config$CREDENTIALS)
    user_data <- credentials_df[credentials_df$CLIENT_ID == CLIENT_ID, ]
    
    if (nrow(user_data) > 0 && user_data$PASSWORD == PASSWORD) {
      CLIENT_SECRET <- user_data$CLIENT_SECRET
      
      if (is.null(CLIENT_SECRET)) {
        return(list(error = "CLIENT_SECRET key not found for user"))
      }
      
      return(list(success = TRUE, CLIENT_SECRET = CLIENT_SECRET))
    } else {
      return(list(error = "Invalid credentials"))
    }
  }, error = function(e) {
    cat(Sys.time(), "[ERROR] Authentication error -", e$message, "\n", file=stderr())
    return(list(error = "Authentication process failed"))
  })
}


# Decode JWT Token
decode_token_info_hmac <- function(token, secret_key) {
  if (is.null(token) || token == "") {
    return(list(status = "error", output = "Empty JWT Token"))
  }
  
  key_raw <- charToRaw(secret_key)
  config_data <- load_config("Config.json")

  if (is.null(config_data)) {
    return(list(status = "error", output = "Failed to load configuration"))
  }
  credentials_df <- as.data.frame(config_data$CREDENTIALS)
  expected_CLIENT_ID <- credentials_df$CLIENT_ID
  expected_CLIENT_SECRET <- credentials_df$CLIENT_SECRET
  
  decoded_token <- tryCatch({
    result <- jwt_decode_hmac(token, secret = key_raw)
    list(status = "success", output = result)
  }, error = function(e) {
    cat(Sys.time(), "[ERROR] Token decoding failed -", e$message, "\n", file=stderr())
    if (grepl("Token has expired", e$message, ignore.case = TRUE)) {
      return(list(status = "error", output = "Token Expired"))
    } else {
      return(list(status = "error", output = "Token is Invalid"))
    }
  })
  
  # If decoding failed, return immediately
  if (is.null(decoded_token) || decoded_token$status == "error") {
    return(list(status = "error", output = decoded_token$output))
  }
  
  # Ensure the decoded_token is successful before checking further conditions
  if (decoded_token$status == "success") {
    
    if (!("CLIENT_ID" %in% names(decoded_token$output)) || !("CLIENT_SECRET" %in% names(decoded_token$output))) {
      return(list(status = "error", output = "Token is Invalid"))
    }
    
    decoded_CLIENT_ID <- decoded_token$output$CLIENT_ID
    print(decoded_CLIENT_ID)
    decoded_CLIENT_SECRET <- decoded_token$output$CLIENT_SECRET
    print(decoded_CLIENT_SECRET)
    
    if (!(decoded_CLIENT_ID %in% expected_CLIENT_ID)) {
      return(list(status = "error", output = "Token is Invalid"))
      
    }
    
    if (!(decoded_CLIENT_SECRET %in% expected_CLIENT_SECRET)) {
      return(list(status = "error", output = "Token is Invalid"))
    }
    
  }
  
  return(list(
    status = "success",
    CLIENT_ID = decoded_token$output$CLIENT_ID,
    CLIENT_SECRET = decoded_token$output$CLIENT_SECRET,
    expiration_time = decoded_token$output$exp
  ))
}

# Function to validate token
validate_token <- function(token, config) {
  secret_key <- "F3E996E7-0135-49C4-97F9-9E0F7CB6A70E"
  decoded_info <- decode_token_info_hmac(token, secret_key)
  
  if (decoded_info$status == "error") {
    return(list(valid = FALSE, error = decoded_info$output))
  }
  
  if (decoded_info$status == "success") {
    # Extract token details only if status is success
    CLIENT_ID <- decoded_info$CLIENT_ID
    CLIENT_SECRET <- decoded_info$CLIENT_SECRET
    expiration_time <- decoded_info$exp  # Assuming the 'exp' field holds the expiration time
    
    # Check if the token has expired
    if (as.numeric(Sys.time()) > expiration_time) {
      #send_graylog(4, "Token expired", list(token = token))
      return(list(valid = FALSE, error = "Token Expired"))
    }
    
    # Proceed with other logic if the token is valid
    return(list(valid = TRUE, CLIENT_ID = CLIENT_ID, CLIENT_SECRET = CLIENT_SECRET, expiration_time = expiration_time))
  }
  
  user_data <- config[config$CLIENT_ID == CLIENT_ID, ]
  
  if (nrow(user_data) == 0) {
    return(list(valid = FALSE, error = "Invalid Client ID"))
  }
  
  stored_CLIENT_SECRET <- user_data$CLIENT_SECRET
  if (CLIENT_SECRET != stored_CLIENT_SECRET) {
    return(list(valid = FALSE, error = "Invalid Client Secret key"))
  }
  
  return(list(valid = TRUE, CLIENT_ID = CLIENT_ID))
}

# Decorator function for token validation
validate_token_decorator <- function(func) {
  function(req) {
    token <- req$HTTP_RTOKEN
    if (is.null(token) || token == "") {
      return(list(status = "error", output = "Missing Token"))
    }
    
    #config <- load_config("config.ini")
    config <- load_config("Config.json")
    validation_result <- validate_token(token, config)
    
    if (!validation_result$valid) {
      return(list(status = "error", output = validation_result$error))
    }
    
    req$CLIENT_ID <- validation_result$CLIENT_ID
    func(req)
  }
}

#execute_code <- function(code_string) {
#  tryCatch({
#    code_string <- gsub("\r", "", code_string)
#    eval_output <- capture.output(eval(parse(text = code_string)))
#    return(list(status = "success", output = as.character(eval_output)))
#  }, error = function(e) {
#    cat(Sys.time(), "[ERROR] Code execution error -", e$message, "\n", file=stderr())
#    return(list(status = "error", output = paste("Error:", e$message)))
#  })
#}


library(R.utils)
execute_code <- function(code_string, timeout_seconds = 10) {
  tryCatch({
    # Removing carriage return characters
    code_string <- gsub("\r", "", code_string)
    
    # Timeout feature: Set a timeout for the code execution
    eval_output <- withTimeout({
      capture.output(eval(parse(text = code_string)))
    }, timeout = timeout_seconds, onTimeout = "error")  # Timeout error if execution exceeds limit
    
    return(list(status = "success", output = as.character(eval_output)))  # Return successful result
    
  }, error = function(e) {
    # Log the error with timestamp and message
    if (grepl("Timeout", e$message)) {
      cat(Sys.time(), "[ERROR] Code execution timed out after", timeout_seconds, "seconds -", e$message, "\n", file=stderr())
    } else {
      cat(Sys.time(), "[ERROR] Code execution error -", e$message, "\n", file=stderr())
    }
    return(list(status = "error", output = paste("Error:", e$message)))  # Return error message
  })
}
