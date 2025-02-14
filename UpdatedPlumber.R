# main.R - API Routes and Function Calls

library(plumber)
source("Utility.R")  # Load the utility file

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

pr <- plumber$new()

# Register API Endpoints
pr$handle("GET", "/ping", ping)
pr$handle("POST", "/rtoken", rtoken)
pr$handle("POST", "/execute", execute_method)

# Fetch existing OpenAPI specification
existing_spec <- pr$getApiSpec()

# Update API metadata (Title & Description)
existing_spec$info$title <- "API Title: R-Console"
existing_spec$info$description <- "\n\nThe R Compiler API is designed to provide a seamless and secure environment for executing R scripts via a RESTful interface. The API incorporates robust authentication mechanisms and structured request handling to ensure authorized access and efficient execution of R code."

# Add descriptions to individual endpoints
existing_spec$paths$`/ping`$get$summary <- "Health Check"
existing_spec$paths$`/ping`$get$description <- "\n\n1. **Ping (GET Method)**:\n- The ping endpoint serves as a health check for the API, verifying server availability.\n- It returns a simple response indicating whether the server is up and running."

existing_spec$paths$`/rtoken`$post$summary <- "Authentication Token"
existing_spec$paths$`/rtoken`$post$description <- "\n\n2. **rtoken (POST Method)**:\n- The rtoken endpoint is responsible for user authentication and authorization.\n- It accepts client_id and password in the request headers and generates a JWT token upon successful validation.\n- The JWT token is required for subsequent API requests to ensure that only authorized users can execute R scripts."

existing_spec$paths$`/execute`$post$summary <- "Execute R Code"
existing_spec$paths$`/execute`$post$description <- "\n\n3. **execute (POST Method)**:\n- The execute endpoint enables users to run R scripts securely.\n- It requires a valid JWT token (obtained from the rtoken endpoint) for authentication.\n- The request payload must be in JSON format, containing the necessary script execution parameters.\n- The response includes the execution status and output, ensuring efficient validation and processing."

# Apply the updated API spec
pr$setApiSpec(existing_spec)

# Run the API
pr$run(port = 8000, swagger = TRUE)
