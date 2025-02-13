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

# Function to write logs to a local log file
write_log_file <- function(level, message, data = list()) {
  log_entry <- paste(Sys.time(), "[", level, "]", message, 
                     if (!is.null(data)) paste(" - ", toJSON(data, auto_unbox = TRUE)), 
                     "\n", sep = "")
  
  write(log_entry, file = "server_logs.txt", append = TRUE)
}

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
    write_log_file("ERROR", "Failed to load configuration", list(error_message = e$message))
    return(NULL)
  })
}
config_data <- load_config("Config.json")


if (!is.null(config_data)) {
  graylog_config <- config_data$GRAYLOG
  
  max_chunk_size <- ifelse(graylog_config$CONNECTION == "wan", 
                           graylog_config$MAX_CHUNK_SIZE_WAN, 
                           graylog_config$MAX_CHUNK_SIZE_LAN)
  
  graylog_details <- list(
    HOST_NAME = graylog_config$HOST_NAME,
    PORT = graylog_config$PORT,
    CONNECTION = graylog_config$CONNECTION,
    MAX_CHUNK_SIZE = max_chunk_size,
    ENVIRONMENT = graylog_config$ENVIRONMENT,
    APPLICATION = graylog_config$APPLICATION
  )
} else {
  write_log_file("ERROR", "Graylog configuration missing in Config.json")
}

# Function to send logs to Graylog
send_graylog <- function(level, message, data = list()) {
  tryCatch({
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
    
    log_entry <- c(log_entry, data)
    
    response <- httr::POST(
      url,
      body = jsonlite::toJSON(log_entry, auto_unbox = TRUE),
      encode = "json"
    )
    
    return(response)
  }, error = function(e) {
    write_log_file("ERROR", paste("Graylog Error:", e$message), list(message = message, data = data))
    return(NULL)
  })
}

# Function to authenticate user
authenticate_user <- function(CLIENT_ID, PASSWORD, config) {
  tryCatch({
    credentials_df <- as.data.frame(config$CREDENTIALS)
    user_data <- credentials_df[credentials_df$CLIENT_ID == CLIENT_ID, ]
    
    if (nrow(user_data) > 0 && user_data$PASSWORD == PASSWORD) {
      CLIENT_SECRET <- user_data$CLIENT_SECRET
      
      if (is.null(CLIENT_SECRET)) {
        send_graylog(3, "Authentication failed: CLIENT_SECRET missing", list(CLIENT_ID = CLIENT_ID))
        return(list(error = "CLIENT_SECRET key not found for user"))
      }
      
      return(list(success = TRUE, CLIENT_SECRET = CLIENT_SECRET))
    } else {
      send_graylog(4, "Invalid credentials", list(CLIENT_ID = CLIENT_ID))
      return(list(error = "Invalid credentials"))
    }
  }, error = function(e) {
    write_log_file("ERROR", "Authentication error", list(error_message = e$message))
    return(list(error = "Authentication process failed"))
  })
}

# Function to decode JWT Token
decode_token_info_hmac <- function(token, secret_key) {
  tryCatch({
    if (is.null(token) || token == "") {
      return(list(status = "error", output = "Empty JWT token"))
    }
    
    key_raw <- charToRaw(secret_key)
    config_data <- load_config("Config.json")
    
    if (is.null(config_data)) {
      return(list(status = "error", output = "Failed to load configuration"))
    }
    
    credentials_df <- as.data.frame(config_data$CREDENTIALS)
    expected_CLIENT_ID <- credentials_df$CLIENT_ID
    expected_CLIENT_SECRET <- credentials_df$CLIENT_SECRET
    
    decoded_token <- jwt_decode_hmac(token, secret = key_raw)
    
    if (!("CLIENT_ID" %in% names(decoded_token)) || !("CLIENT_SECRET" %in% names(decoded_token))) {
      return(list(status = "error", output = "Invalid token structure"))
    }
    
    if (!(decoded_token$CLIENT_ID %in% expected_CLIENT_ID)) {
      return(list(status = "error", output = "Invalid CLIENT_ID"))
    }
    
    if (!(decoded_token$CLIENT_SECRET %in% expected_CLIENT_SECRET)) {
      return(list(status = "error", output = "Invalid CLIENT_SECRET"))
    }
    
    return(list(
      status = "success",
      CLIENT_ID = decoded_token$CLIENT_ID,
      CLIENT_SECRET = decoded_token$CLIENT_SECRET,
      expiration_time = decoded_token$exp
    ))
  }, error = function(e) {
    send_graylog(3, "Token decoding failed", list(error_message = e$message))
    write_log_file("ERROR", "Token decoding failed", list(error_message = e$message))
    return(list(status = "error", output = "Invalid token"))
  })
}

# Function to validate token
validate_token <- function(token, config) {
  tryCatch({
    secret_key <- "F3E996E7-0135-49C4-97F9-9E0F7CB6A70E"
    decoded_info <- decode_token_info_hmac(token, secret_key)
    
    if (decoded_info$status == "error") {
      send_graylog(4, "Token validation failed", list(error_message = decoded_info$output))
      return(list(valid = FALSE, error = decoded_info$output))
    }
    
    if (as.numeric(Sys.time()) > decoded_info$expiration_time) {
      send_graylog(4, "Token expired", list(token = token))
      return(list(valid = FALSE, error = "Token expired"))
    }
    
    return(list(valid = TRUE, CLIENT_ID = decoded_info$CLIENT_ID))
  }, error = function(e) {
    write_log_file("ERROR", "Token validation failed", list(error_message = e$message))
    return(list(valid = FALSE, error = "Token validation process failed"))
  })
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
    write_log_file("ERROR", "Code execution error", list(error_message = e$message, code = code_string))
    return(list(status = "error", output = paste("Error:", e$message)))
  })
}
