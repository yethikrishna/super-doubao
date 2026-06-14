# Super Doubao

Super Doubao is a secure sandbox runtime for AI agents. It gives an AI assistant (such as Claude Code) a real, isolated environment where it can execute Python code, read and write files, inspect its own runtime, and more — all over a clean HTTP API with cryptographic request verification.

---

## Why This Exists

AI agents need to do more than chat. They need to run code, process files, and interact with a system in real time. Super Doubao provides that capability as a self-contained, deployable service. Instead of building a custom execution layer for every AI application, you deploy this once and point your agent at it.

---

## What It Can Do

### Python Code Execution
Run arbitrary Python code inside a persistent Jupyter kernel. State is preserved between calls within a session, so variables, imports, and outputs accumulate exactly as they would in an interactive notebook. Supports async execution, configurable timeouts, and static analysis to predict whether code will time out before it even runs.

### File Management
Upload files to the sandbox (single file or multipart for large files via presigned S3 URLs), download files back out, and list directory contents. Handles any file type — code, data, PDFs, spreadsheets, images, archives.

### Text Editor
A structured file editing API that mirrors what a developer does at a terminal:
- **view** — read a file or directory
- **create** — make a new file
- **write** — overwrite a file
- **str_replace** — targeted find-and-replace inside a file
- **find** — search for a string across files
- **zip_and_upload** — compress a directory and upload to a presigned URL

All operations work on single files or batches of files concurrently.

### Sandbox Metadata
Query the runtime environment: OS name and version, Python version and path, and the full list of installed packages with their versions. Useful for agents that need to reason about what tools are available before writing code.

### Metrics
Track which Python modules have been loaded during a session. Useful for observability and debugging.

### Health Check
`GET /vm/exec/api/healthz` — returns `{"status": "ok"}` when the service (including the Chrome debug port, if used) is ready. Suitable for container liveness and readiness probes.

---

## Data Science Stack Included

The runtime comes with a comprehensive set of pre-installed packages so agents can do real work out of the box:

- **Numerical**: NumPy, SciPy, Pandas
- **ML / AI**: Scikit-learn, TensorFlow, XGBoost, LightGBM, CatBoost
- **Visualization**: Matplotlib, Seaborn, Plotly
- **NLP**: NLTK, TextBlob, Gensim, jieba
- **Document handling**: PyPDF2, python-docx, python-pptx, openpyxl, PyMuPDF
- **Web / APIs**: requests, aiohttp, BeautifulSoup, FastAPI, Flask
- **Databases**: pymongo, redis, psutil
- **Dev tools**: GitPython, Docker, pytest, coverage

---

## API Reference

All endpoints are mounted under `/vm/exec/api`.

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/code_interpreter/kernel_v2` | Execute Python code in a Jupyter kernel |
| `POST` | `/file/upload` | Upload a file to the sandbox |
| `POST` | `/file/multipart_upload_to_s3` | Upload a large file in parts to S3 |
| `GET`  | `/file` | Download a file from the sandbox |
| `POST` | `/text_editor` | File view / create / write / str_replace / find / zip |
| `GET`  | `/v1/sandbox` | OS info, Python version, installed packages |
| `GET`  | `/metrics/loaded_modules` | Loaded Python modules in the current session |
| `GET`  | `/healthz` | Service health check |

---

## Running the Server

```bash
cd python_server
pip install -r requirements_ci.txt
python start_server.py --port 9999 --log-level info
```

Or via the container entrypoint:
```bash
./entrypoint.sh
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SECURITY_PK` | Yes | Base64-encoded RSA public key used to verify request signatures |
| `WS_ID` | Yes | Workspace identifier, validated on authenticated requests |
| `CI_PYTHON_SERVER_PORT` | No | Port to listen on (default: `9999`) |
| `ENABLE_CI_SERVER` | No | Set to `false` to disable the server (default: `true`) |
| `CODE_INTERPRETER_TIMEOUT` | No | Default kernel execution timeout in seconds (default: `45`) |
| `REQUEST_TIMEOUT` | No | HTTP request timeout in seconds (default: `60`) |
| `CHROME_INSTANCE_PATH` | No | Path to a Chrome binary (for browser-integrated deploys) |
| `CHROME_HEADLESS` | No | Set to `True` to run Chrome headless |
| `PROXY_SERVER` | No | HTTP proxy server for outbound requests |
| `PROXY_USERNAME` | No | Proxy authentication username |
| `PROXY_PASSWORD` | No | Proxy authentication password |

---

## Security

Every incoming request is verified using RSA signature validation. The server checks:
- A valid signature header signed with the private key matching `SECURITY_PK`
- A timestamp within a 10-minute window to prevent replay attacks

Requests without a valid signature are rejected before any business logic runs.

---

## Deploy Readiness

The service is production-ready for all currently implemented endpoints. The following capabilities are **intentionally deferred** — they are architecturally planned and the groundwork is in place, but their implementation is meant to be completed separately based on deployment needs:

- **Browser automation** (`/browser/*`) — Chrome DevTools Protocol integration for web interaction
- **Terminal access** (`/terminal/*`) — Interactive shell session management
- **Sandbox initialization** (`/init-sandbox`) — Custom sandbox bootstrap logic

These are not bugs or missing pieces — they are extension points. Deploy without them and add them when your use case requires them.

---

## Running Tests

```bash
cd python_server
python -m pytest tests/test_fixes.py -v
```
