# main.R
source("/app/UpdatedPlumber.R")
#source("/app/Test.R")
#source("/app/Tetsting.R")

# If you want to start a Plumber API
library(plumber)
pr <- plumb("/app/UpdatedPlumber.R")
pr$run(port = 5000, host = "0.0.0.0")
