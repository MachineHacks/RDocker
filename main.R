# main.R
source("/app/UpdatedPlumber.R")

# If you want to start a Plumber API
library(plumber)
pr <- plumb("/app/UpdatedPlumber.R")
pr$run(port = 8000, host = "0.0.0.0")
