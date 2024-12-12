# Run the Python Flask app (this starts the Flask server)
system("python3 /app/app_raw.py &")  # Running Python in the background
sys.sleep(5)

# main.R
source("/app/UpdatedPlumber.R")
#source("/app/Test.R")
#source("/app/Tetsting.R")

# If you want to start a Plumber API
library(plumber)
pr <- plumb("/app/UpdatedPlumber.R")
pr$run(port = 5000, host = "0.0.0.0")
