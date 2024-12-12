from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

@app.route('/upload', methods=['POST'])
def upload_raw_code():
    try:
        # Get raw text data from the request body
        r_code = request.data.decode('utf-8')  # Decode raw bytes to string

        # Normalize the R code (strip carriage returns and unnecessary spaces)
        r_code = r_code.replace("\r", "").strip()

        # Log the raw R code for debugging
        print(f"Normalized R code to send to R API:\n{r_code}")

        # Send the R code to the R API
        r_api_url = "http://localhost:8000/execute"  # R API endpoint
        headers = {'Content-Type': 'text/plain'}  # Raw text content type
        response = requests.post(r_api_url, data=r_code, headers=headers)

        # Handle the response from the R API
        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({'status': 'error', 'message': 'Error from R API', 'details': response.text}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, port=5000)

from flask import Flask
import logging
from logging import FileHandler

app = Flask(__name__)

handler = FileHandler('error.log')
handler.setLevel(logging.DEBUG)
app.logger.addHandler(handler)

@app.route('/')
def index():
	return 'Hello IIS from Flask'

@app.route('/Hello')
def hello_world():
	return 'Hello World!'
	
if __name__ == '__main__':
	app.run()
