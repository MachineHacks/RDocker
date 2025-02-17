# main.R - API Routes and Function Calls

library(plumber)
source("Utility.R")  # Load the utility file

# Simple GET endpoint to check if the API is working
#* @get /ping
ping <- function() {
  tryCatch({
    #print("I am alive, use the rconsole execute method to run the R program")
    return(list(message = "I am alive, use the rconsole execute method to run the R program"))
  }, error = function(e) {
    cat("Error in /ping:", e$message, "\n", file = stderr())
    return(list(status = "error", message = "An error occurred in /ping"))
  })
}

#* @post /rtoken
#* @serializer json
rtoken <- function(req) {
  tryCatch({
    CLIENT_ID <- req$HTTP_CLIENT_ID
    PASSWORD <- req$HTTP_PASSWORD
    
    if (is.null(CLIENT_ID) || CLIENT_ID == "") {
      cat("Error: Missing CLIENT_ID\n", file = stderr())
      return(list(status = "error", output = "Missing CLIENT_ID"))
    }
    if (is.null(PASSWORD) || PASSWORD == "") {
      cat("Error: Missing PASSWORD\n", file = stderr())
      return(list(status = "error", output = "Missing PASSWORD"))
    }
    
    config <- load_config("Config.json")
    secret_key <- "F3E996E7-0135-49C4-97F9-9E0F7CB6A70E"
    
    auth_result <- authenticate_user(CLIENT_ID, PASSWORD, config)
    #print(auth_result)
    
    if (!is.list(auth_result) || !"success" %in% names(auth_result) || !auth_result$success) {
      cat("Error: Invalid Client_ID or PASSWORD\n", file = stderr())
      return(list(status = "error", output = "Invalid Client_ID or PASSWORD"))
    }
    
    CLIENT_SECRET <- auth_result$CLIENT_SECRET
    
    if (is.null(CLIENT_SECRET) || CLIENT_SECRET == "") {
      cat("Error: Security key missing for CLIENT_ID:", CLIENT_ID, "\n", file = stderr())
      return(list(status = "error", output = "Security key not found for user"))
    }
    
    expiration_time <- as.numeric(Sys.time()) + 3600
    payload <- jwt_claim(CLIENT_ID = CLIENT_ID, exp = expiration_time, CLIENT_SECRET = auth_result$CLIENT_SECRET)
    token <- jwt_encode_hmac(payload, secret = charToRaw(secret_key))
    
    return(list(status = "success", token = token))
  }, error = function(e) {
    cat("Error in /rtoken:", e$message, "\n", file = stderr())
    return(list(status = "error", message = "An error occurred in /rtoken"))
  })
}

#* @post /execute
#* @param token The JWT token for authentication
execute_method <- validate_token_decorator(function(req) {
  tryCatch({
    body_content <- fromJSON(req$postBody, simplifyVector = FALSE)
    
    if (!("files" %in% names(body_content)) || length(body_content$files) == 0 || !"content" %in% names(body_content$files[[1]])) {
      cat("Error: Invalid request at /execute\n", file = stderr())
      return(list(status = "error", output = "Invalid request"))
    }
  
    code_string <- body_content$files[[1]]$content
    if (!is_code_safe(code_string)) {
      cat("Error: Restricted command detected at /execute\n", file = stderr())
      return(list(status = "error", output = "Execution of restricted commands is not allowed"))
    }
    
    code_string <- normalize_quotes(code_string)
    execution_result <- execute_code(code_string)
    
    return(execution_result)
  }, error = function(e) {
    cat("Error in /execute:", e$message, "\n", file = stderr())
    return(list(status = "error", message = "An error occurred in /execute"))
  })
})
