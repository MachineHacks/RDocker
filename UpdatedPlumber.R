library(plumber)

# Function to execute R code from a string
execute_code <- function(code_string) {
  tryCatch({
    # Normalize line endings by removing \r characters
    code_string <- gsub("\r", "", code_string)
    
    # Trim unnecessary spaces
    code_string <- trimws(code_string)
    
    # Debug: Print the normalized code
    cat("Normalized code to execute:\n")
    cat(code_string, "\n\n")
    
    # Parse and evaluate the code
    eval_output <- eval(parse(text = code_string))
    
    # Return the result
    return(list(status = "success", output = as.character(eval_output)))
  }, error = function(e) {
    # Handle errors gracefully
    return(list(status = "error", output = paste("Error during execution:", e$message)))
  })
}

# Define the Plumber API endpoint
#* @post /execute
function(req) {
  tryCatch({
    # Retrieve raw body content
    body_content <- req$body
    
    # Convert raw content to character string
    if (is.raw(body_content)) {
      code_string <- rawToChar(body_content)
    } else {
      stop("Request body is not in raw format.")
    }
    
    # Debug: Log the raw body content
    cat("Raw body content:\n", code_string, "\n")
    
    # Normalize line endings and trim spaces
    code_string <- gsub("\r", "", code_string)
    code_string <- trimws(code_string)
    
    # Debug: Log the normalized code
    cat("Normalized R code:\n", code_string, "\n")
    
    # Execute the R code
    result <- execute_code(code_string)
    
    # Return the result
    return(result)
  }, error = function(e) {
    return(list(status = "error", output = e$message))
  })
}

# To run this script:
# Save it as `r_api.R`, then execute the following in your terminal:
# > plumber::plumb("r_api.R")$run(port = 8000)
