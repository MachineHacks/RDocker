# main.R
source("/app/plumber_app.R")
#source("/app/Test.R")
#source("/app/Tetsting.R")

# If you want to start a Plumber API
library(plumber)
pr <- plumb("/app/plumber_app.R")
pr$run(port = 8000, host = "104.211.66.42")
