# main.R - API Routes and Function Calls

library(plumber)
source("Utility.R")  # Load the utility file

config <- load_config("Config.json")
# Extract API Metadata
api_title <- config$API$TITLE
api_description <- config$API$DESCRIPTION

#* @apiTitle Dynamic API Title
#* @apiDescription Dynamic API Description


# Simple GET endpoint to check if the API is working
#* @get /ping
ping <-function() {
  print("I am alive, use the rconsole execute method to run the R program")
  return(list(message = "I am alive, use the rconsole execute method to run the R program"))
}

#* @post /rtoken
#* @serializer json
rtoken <- function(req) {
  CLIENT_ID <- req$HTTP_CLIENT_ID
  PASSWORD <- req$HTTP_PASSWORD
  
  if (is.null(CLIENT_ID) || CLIENT_ID == "") {
    send_graylog(3, "Missing CLIENT_ID", list(endpoint = "/rtoken"))
    return(list(status = "error", output = "Missing CLIENT_ID"))
  }
  if (is.null(PASSWORD) || PASSWORD == "") {
    send_graylog(3, "Missing PASSWORD", list(endpoint = "/rtoken"))
    return(list(status = "error", output = "Missing PASSWORD"))
  }
  
  config <- load_config("Config.json")
  secret_key <- "F3E996E7-0135-49C4-97F9-9E0F7CB6A70E"
  
  auth_result <- authenticate_user(CLIENT_ID, PASSWORD, config)
  #print(auth_result)
  
  # Check if authentication was successful
  if (!is.list(auth_result) || !"success" %in% names(auth_result) || !auth_result$success) {
    send_graylog(3, "Invalid Client_ID or PASSWORD", list(endpoint = "/rtoken", CLIENT_ID = CLIENT_ID))
    return(list(status = "error", output = "Invalid Client_ID or PASSWORD"))
  }
  
  # Extract the security key (user-specific) from authentication result
  CLIENT_SECRET <- auth_result$CLIENT_SECRET
  
  # Check if the security key exists
  if (is.null(CLIENT_SECRET) || CLIENT_SECRET == "") {
    send_graylog(3, "Security key missing", list(endpoint = "/rtoken", CLIENT_ID = CLIENT_ID))
    return(list(status = "error", output = "Security key not found for user"))
  }
  
  expiration_time <- as.numeric(Sys.time()) + 3600
  payload <- jwt_claim(CLIENT_ID = CLIENT_ID, exp = expiration_time, CLIENT_SECRET = auth_result$CLIENT_SECRET)
  token <- jwt_encode_hmac(payload, secret = charToRaw(secret_key))
  
  return(list(status = "success", token = token))
}

#* @post /execute
#* @param token The JWT token for authentication
execute_method <- validate_token_decorator(function(req) {
  body_content <- fromJSON(req$postBody, simplifyVector = FALSE)
  
  if (!("files" %in% names(body_content)) || length(body_content$files) == 0 || !"content" %in% names(body_content$files[[1]])) {
    send_graylog(3, "Invalid request format", list(endpoint = "/execute"))
    return(list(status = "error", output = "Invalid request"))
  }
  
  code_string <- body_content$files[[1]]$content
  if (!is_code_safe(code_string)) {
    return(list(status = "error", output = "Execution of restricted commands is not allowed"))
  }
  
  code_string <- normalize_quotes(code_string)
  execution_result <- execute_code(code_string)
  
  return(execution_result)
})

# API Setup
pr <- plumber$new()

# Set API Metadata (Title & Description)
#api_spec <- list(
#  openapi = "3.0.3",
#  info = list(
#    title = "New API Title",
#    description = "Updated API Description",
#    version = "1.0.0"
#  )
#)

pr <- Plumber$new()

pr$handle("GET", "/ping", ping)
pr$handle("POST", "/rtoken", rtoken)
pr$handle("POST", "/execute", execute_method)

#existing_spec <- pr$getApiSpec()
#existing_spec$info$title <- "API Title: R-Console"
#existing_spec$info$description <- "Tttttt"
#pr$setApiSpec(existing_spec) 

# Fetch existing OpenAPI spec
existing_spec <- pr$getApiSpec()
existing_spec$info$title <- api_title
existing_spec$info$description <- api_description

# Apply updated spec
pr$setApiSpec(existing_spec)

pr$run(port = 8000, swagger = TRUE) 
