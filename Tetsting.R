library(plumber)

# Simple GET endpoint to check if the API is working
#* @get /test
function () 
{
  print("The Docker container and Plumber API are working!")
  return(list(message = "The Docker container and Plumber API are working!"))
}
function (req) 
{
  body_content <- req$body
  code_string <- if (is.raw(body_content)) 
    rawToChar(body_content)
  else body_content
  code_string <- normalize_quotes(code_string)
  if (is.null(code_string) || nchar(code_string) == 0) {
    return(list(status = "error", output = "Decoded code string is empty or invalid"))
  }
  execute_code(code_string)
}

# Start the Plumber API
pr <- plumber::plumb('/app/plumber_app.R')
pr$run(host = '0.0.0.0', port = 8000)
