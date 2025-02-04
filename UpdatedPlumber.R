library(jsonlite)
library(jose)
library(digest)
library(plumber)
library(openssl)
library(base64enc)
library(ini)

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

# Load configuration from INI file
load_config <- function(config_path) {
  config_list <- read.ini(config_path)
  config_list[["SecretKey"]] <- NULL
  
  config_df <- do.call(rbind, lapply(config_list, function(x) {
    data.frame(username = x$username,
               password = x$password,
               security_key = x$security_key,
               stringsAsFactors = FALSE)
  }))
  
  return(config_df)
}

# Authenticate user against the stored config
authenticate_user <- function(username, password, config) {
  user_data <- config[config$username == username, ]  
  
  if (nrow(user_data) > 0 && user_data$password == password) {
    security_key <- user_data$security_key
    if (is.null(security_key)) {
      return(list(error = "Security key not found for user"))
    }
    return(list(success = TRUE, security_key = security_key))  
  } else {
    return(list(error = "Invalid credentials"))  
  }
}

# Generate JWT token
#* @post /rtoken
#* @serializer json
rtoken <- function(req) {
  username <- req$HTTP_USERNAME  
  password <- req$HTTP_PASSWORD  
  
  if (is.null(username) || username == "") {
    return(list(status = "error", output = "Missing username"))
  }
  if (is.null(password) || password == "") {
    return(list(status = "error", output = "Missing password"))
  }
  
  config_path <- "config.ini"
  config <- load_config(config_path)
  configread <- read.ini(config_path)
  secret_key <- configread$SecretKey$secretkey
  
  auth_result <- authenticate_user(username, password, config)
  
  if (!is.list(auth_result) || !"success" %in% names(auth_result) || !auth_result$success) {
    return(list(status = "error", output = "Invalid username or password"))
  }
  
  security_key <- auth_result$security_key
  if (is.null(security_key) || security_key == "") {
    return(list(status = "error", output = "Security key not found for user"))
  }
  
  expiration_time <- as.numeric(Sys.time()) + 3600  
  
  payload <- jwt_claim(
    username = username, 
    exp = expiration_time, 
    security_key = security_key  
  )
  
  key_raw <- charToRaw(secret_key)
  token <- jwt_encode_hmac(payload, secret = key_raw)  
  
  return(list(status = "success", token = token))
}

# Decode JWT Token
decode_token_info_hmac <- function(token, secret_key) {
  if (is.null(token) || token == "") {
    return(list(status = "error", output = "Empty JWT token"))
  }
  
  key_raw <- charToRaw(secret_key)
  
  config_data <- tryCatch({
    config_path = "config.ini"
    load_config(config_path)
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(config_data)) {
    return(list(status = "error", output = "Failed to load configuration"))
  }
  
  expected_username <- config_data$username
  expected_security_key <- config_data$security_key
  
  decoded_token <- tryCatch({
    jwt_decode_hmac(token, secret = key_raw)
  }, error = function(e) {
    return(NULL)
  })
  
  if (is.null(decoded_token)) {
    return(list(status = "error", output = "Invalid JWT token"))
  }
  
  decoded_username <- decoded_token$username
  decoded_security_key <- decoded_token$security_key
  
  if (!(decoded_username %in% expected_username)) {
    return(list(status = "error", output = "Invalid username in JWT"))
  }
  
  if (!(decoded_security_key %in% expected_security_key)) {
    return(list(status = "error", output = "Invalid security key in JWT"))
  }
  
  return(list(
    status = "success",
    username = decoded_token$username,
    security_key = decoded_token$security_key,
    expiration_time = decoded_token$exp
  ))
}

# Function to validate token
validate_token <- function(token, config) {
  configread <- read.ini("config.ini")
  secret_key <- configread$SecretKey$secretkey
  
  decoded_info <- decode_token_info_hmac(token, secret_key)
  
  if (decoded_info$status != "success") {
    return(list(valid = FALSE, error = "Invalid token format"))
  }
  
  username <- decoded_info$username
  security_key <- decoded_info$security_key
  expiration_time <- decoded_info$expiration_time
  
  current_time <- as.numeric(Sys.time())
  if (expiration_time < current_time) {
    return(list(valid = FALSE, error = "Token expired"))
  }
  
  user_data <- config[config$username == username, ]
  
  if (nrow(user_data) == 0) {
    return(list(valid = FALSE, error = "Invalid username"))
  }
  
  stored_security_key <- user_data$security_key
  if (security_key != stored_security_key) {
    return(list(valid = FALSE, error = "Invalid security key"))
  }
  
  return(list(valid = TRUE, username = username))
}

# Decorator function to validate token 
validate_token_decorator <- function(func) {
  function(req) {
    token <- req$HTTP_RTOKEN
    if (is.null(token) || token == "") {
      return(list(status = "error", output = "Missing token in headers"))
    }
    
    config_path <- "config.ini"
    config <- load_config(config_path)
    
    validation_result <- validate_token(token, config)
    
    if (!validation_result$valid) {
      return(list(status = "error", output = validation_result$error))
    }
    
    req$username <- validation_result$username  
    func(req)  
  }
}

#* @post /execute
#* @param token The JWT token for authentication
execute_method <- validate_token_decorator(function(req) {
  body_content <- fromJSON(req$postBody, simplifyVector = FALSE)
  
  if (!("files" %in% names(body_content)) || length(body_content$files) == 0 || !"content" %in% names(body_content$files[[1]])) {
    return(list(status = "error", output = "Invalid request format"))
  }
  
  code_string <- body_content$files[[1]]$content
  if (!is_code_safe(code_string)) {
    return(list(status = "error", output = "Execution of restricted commands is not allowed"))
  }
  
  code_string <- normalize_quotes(code_string)
  execution_result <- execute_code(code_string)
  
  return(execution_result)
})

# Function to execute R code and handle errors
execute_code <- function(code_string) {
  tryCatch({
    code_string <- gsub("\r", "", code_string) 
    eval_output <- eval(parse(text = code_string))
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}
