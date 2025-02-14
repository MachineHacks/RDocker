## R-Console Setup & Troubleshooting

# R Console Application

## Overview
This project provides an R compiler for the **SW5 application**, enabling users to execute R programs in the backend. The application is secured using JWT authentication and exposes three primary API endpoints: `ping`, `rtoken`, and `execute`.

## API Endpoints

### 1. **Ping Endpoint** (`GET /ping`)
- **Purpose**: Used to check server connectivity and ensure the service is running.
- **Response**: Returns a confirmation message indicating the API is alive.

### 2. **Token Generation Endpoint** (`POST /rtoken`)
- **Purpose**: Generates a JWT token required for executing R code securely.
- **Security**:
  - Only authorized users can obtain a token.
  - The client must provide valid `CLIENT_ID` and `PASSWORD` in the request headers.
  - The provided credentials are validated against predefined values.
- **Response**:
  - If authentication is successful, a JWT token is returned.
  - If authentication fails, an error message is returned.

### 3. **Code Execution Endpoint** (`POST /execute`)
- **Purpose**: Executes an R program provided by the user.
- **Security**:
  - Requires a valid JWT token in the request headers (`rtoken` variable).
  - The token is validated before execution.
  - Token expiration is set to **one hour**. If the session remains idle for over an hour, the token expires, and the user must generate a new one.
- **Request Body (JSON Format)**:
  ```json
  {
    "language": "RLanguage",
    "stdin": "Test123",
    "files": [
      {
        "name": "Dec.py",
        "content": "library(car);data(Prestige);head(Prestige)"
      }
    ]
  }
  ```
- **Response**:
  - If the token is valid, the R script is executed, and the output is returned.
  - If the token is invalid or expired, an error message is returned.
  
## New Libraries Added
The following R libraries have been added to the application to enhance functionality:

- **Core Libraries:**
  - `plumber` – API framework for R
  - `car` – Companion to Applied Regression
  - `dynlm` – Dynamic Linear Models
  - `Mfx` – Marginal Effects for Discrete & Count Data Models
  - `jsonlite` – JSON Handling in R
  - `jose` – JSON Web Token Handling
  - `digest` – Cryptographic Hashing
  - `base64enc` – Base64 Encoding
- **Additional Packages:**
  - `AER`, `cragg`, `moments`, `plm`, `sandwich`, `stargazer`, `tseries`, `urca`, `vars`, `brant`, `erer`, `nnet`, `marginaleffects`, `usmap`

## Adding New R Libraries to the Docker Image

If you need to add a new R library to the Docker image, follow these steps:

1. Open the `Dockerfile` located in the project directory.
2. Locate the section where R libraries are installed. Typically, it looks like this:
   ```dockerfile
   RUN R -e "install.packages(c('plumber', 'car', 'dynlm', 'Mfx', 'jsonlite', 'jose', 'digest', 'ini', 'base64enc', 'httr', 'AER', 'cragg', 'moments', 'plm', 'sandwich', 'stargazer', 'tseries', 'urca', 'vars', 'brant', 'erer', 'nnet', 'marginaleffects', 'usmap'))"
   ```
3. Add the new library to the list inside the `install.packages()` function. Example: If you want to add `ggplot2`, update the line as follows:
   ```dockerfile
   RUN R -e "install.packages(c('plumber', 'car', 'dynlm', 'Mfx', 'jsonlite', 'jose', 'digest', 'ini', 'base64enc', 'httr', 'AER', 'cragg', 'moments', 'plm', 'sandwich', 'stargazer', 'tseries', 'urca', 'vars', 'brant', 'erer', 'nnet', 'marginaleffects', 'usmap', 'ggplot2'))"
   ```
4. Save the changes to the `Dockerfile`.
5. Rebuild the Docker image using the following command:
   ```sh
   docker build -t r_console_app .
   ```
6. Restart the container to apply the changes:
   ```sh
   docker run -d -p 8000:8000 --name r_console_app_container r_console_app
   ```
7. Verify that the new library has been installed by running an R script inside the container.

## Security Measures
- Authentication is enforced through JWT tokens.
- Credentials (`CLIENT_ID`, `PASSWORD`) are validated against predefined values.
- Tokens expire after **one hour** of inactivity.
- Any tampering with the token results in an **Invalid Token** response.

## Deployment
- The application is developed using **R Plumber** to expose API endpoints.
- The API runs on **port 8000** with Swagger enabled for API documentation.

## Usage
1. **Check server status**: Send a `GET` request to `/ping`.
2. **Generate a token**: Send a `POST` request to `/rtoken` with valid credentials.
3. **Execute an R script**:
   - Use the token from `/rtoken` in the request headers.
   - Send a `POST` request to `/execute` with the R script in JSON format.
   
## Conclusion
This R Compiler API for SW5 provides a secure and efficient way to execute R scripts remotely while ensuring authentication and validation mechanisms are in place.
