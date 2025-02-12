# utility.R - Helper and Validation Functions

library(jsonlite)
library(jose)
library(digest)
library(openssl)
library(base64enc)
library(httr)
library(jsonlite)

# Restricted commands to be avoided
restricted_commands <- c( "install.packages","remove.packages","system", "unlink", "eval", "parse", "load", "attach", "sink")

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
  config <- fromJSON(config_path)
  return(config)
}

config_data <- load_config("Config.json")

# Extract Graylog details
graylog_config <- config_data$GRAYLOG

# Select the appropriate MAX_CHUNK_SIZE based on CONNECTION type
max_chunk_size <- ifelse(graylog_config$CONNECTION == "wan", 
                         graylog_config$MAX_CHUNK_SIZE_WAN, 
                         graylog_config$MAX_CHUNK_SIZE_LAN)

# Store extracted details in a list
graylog_details <- list(
  HOST_NAME = graylog_config$HOST_NAME,
  PORT = graylog_config$PORT,
  CONNECTION = graylog_config$CONNECTION,
  MAX_CHUNK_SIZE = max_chunk_size,
  ENVIRONMENT = graylog_config$ENVIRONMENT,
  APPLICATION = graylog_config$APPLICATION
)

# Function to send logs to Graylog
send_graylog <- function(level, message, data = list()) {
  url <- paste0("https://", graylog_details$HOST_NAME, ":", graylog_details$PORT, "/gelf")
  
  log_entry <- list(
    version = "1.1",
    host = Sys.info()["nodename"],
    short_message = message,
    level = level,
    environment = graylog_details$ENVIRONMENT,
    application = graylog_details$APPLICATION,
    timestamp = as.numeric(Sys.time())
  )
  
  # Merge additional data
  log_entry <- c(log_entry, data)
  
  # Send log to Graylog
  response <- tryCatch({
    httr::POST(
      url,
      body = jsonlite::toJSON(log_entry, auto_unbox = TRUE),
      encode = "json"
    )
  }, error = function(e) {
    print(paste("Error sending log to Graylog:", e$message))
    return(NULL)
  })
  
  return(response)
}

# Authenticate user against the stored config
authenticate_user <- function(CLIENT_ID, PASSWORD, config) {
  credentials_df <- as.data.frame(config$CREDENTIALS)  # Convert to dataframe
  user_data <- credentials_df[credentials_df$CLIENT_ID == CLIENT_ID, ]  # F

  # Check if user data is found and the password matches
  if (nrow(user_data) > 0 && user_data$PASSWORD == PASSWORD) {
    # Retrieve the security key for the authenticated user
    CLIENT_SECRET <- user_data$CLIENT_SECRET  # Get security key from the user data
    
    # Ensure the security key is available
    if (is.null(CLIENT_SECRET)) {
      send_graylog(3, "Authentication failed: CLIENT_SECRET missing", list(CLIENT_ID = CLIENT_ID))
      return(list(error = "CLIENT_SECRET key not found for user"))
    }
    
    return(list(success = TRUE, CLIENT_SECRET = CLIENT_SECRET))  # Return success and security key
  } else {
    send_graylog(4, "Invalid credentials", list(CLIENT_ID = CLIENT_ID))
    return(list(error = "Invalid credentials"))  # Authentication failed
  }
}

# Decode JWT Token
decode_token_info_hmac <- function(token, secret_key) {
  if (is.null(token) || token == "") {
    return(list(status = "error", output = "Empty JWT token"))
  }
  
  key_raw <- charToRaw(secret_key)
  
  config_data <- tryCatch({
    load_config("Config.json")
  }, error = function(e) {
    send_graylog(3, "Failed to load configuration", list(error_message = e$message))
    error_msg <- e$message
  })
  
  if (is.null(config_data)) {
    return(list(status = "error", output = "Failed to load configuration"))
  }
  credentials_df <- as.data.frame(config_data$CREDENTIALS)
  expected_CLIENT_ID <- credentials_df$CLIENT_ID
  expected_CLIENT_SECRET <- credentials_df$CLIENT_SECRET
  
  decoded_token <- tryCatch({
    result <- jwt_decode_hmac(token, secret = key_raw)
    list(status = "success", output = result ) 
  }, error = function(e) {
    print(paste("Error:", e$message))
    if (grepl("Token has expired", e$message, ignore.case = TRUE)) {
      return(list(status = "error", output = "Token expired"))
    } else {
      send_graylog(3, "Token decoding failed", list(error_message = e$message))
      return(list(status = "error", output = "Invalid token 84"))
    }
  })
  
  # If decoding failed, return immediately
  if (is.null(decoded_token) || decoded_token$status == "error") {
    return(list(status = "error", output = decoded_token$output))
    #return(decoded_token)  # Directly return the error object
  }
  
  # Ensure the decoded_token is successful before checking further conditions
  if (decoded_token$status == "success") {
    
    if (!("CLIENT_ID" %in% names(decoded_token$output)) || !("CLIENT_SECRET" %in% names(decoded_token$output))) {
      return(list(status = "error", output = "Invalid token 95"))
    }
    
    decoded_CLIENT_ID <- decoded_token$output$CLIENT_ID
    decoded_CLIENT_SECRET <- decoded_token$output$CLIENT_SECRET
    
    if (!(decoded_CLIENT_ID %in% expected_CLIENT_ID)) {
      return(list(status = "error", output = "Invalid token 102"))
      }
    
    if (!(decoded_CLIENT_SECRET %in% expected_CLIENT_SECRET)) {
      return(list(status = "error", output = "Invalid token 106"))
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
    send_graylog(4, "Token validation failed", list(error_message = decoded_info$output))
    return(list(valid = FALSE, error = decoded_info$output))
  }
  
  if (decoded_info$status == "success") {
    # Extract token details only if status is success
    CLIENT_ID <- decoded_info$CLIENT_ID
    CLIENT_SECRET <- decoded_info$CLIENT_SECRET
    expiration_time <- decoded_info$exp  # Assuming the 'exp' field holds the expiration time
    
    # Check if the token has expired
    if (as.numeric(Sys.time()) > expiration_time) {
      send_graylog(4, "Token expired", list(token = token))
      return(list(valid = FALSE, error = "Token expired"))
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
      return(list(status = "error", output = "Missing token"))
    }
    
    config <- load_config("Config.Json")
    validation_result <- validate_token(token, config)
    
    if (!validation_result$valid) {
      return(list(status = "error", output = validation_result$error))
    }
    
    req$CLIENT_ID <- validation_result$CLIENT_ID
    func(req)
  }
}

# Function to execute R code
execute_code <- function(code_string) {
  tryCatch({
    code_string <- gsub("\r", "", code_string)
    eval_output <- eval(parse(text = code_string))
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    send_graylog(3, "Code execution error", list(error_message = e$message, code = code_string))
    return(list(status = "error", output = paste("Error:", e$message)))
  })
}
