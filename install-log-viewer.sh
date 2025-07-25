#!/bin/bash

set -e

# Prompt for user inputs
read -p "Enter the full path to the PM2 log file: " LOG_PATH
read -p "Enter a unique port for this log viewer (e.g., 8900, 8901): " APP_PORT
read -p "Enter the App name for URL path (e.g., BE-logs): " APP_NAME
read -p "Enter the public IP of your EC2 instance: " PUBLIC_IP

# Validate inputs
if [[ -z "$LOG_PATH" || -z "$APP_PORT" || -z "$APP_NAME" || -z "$PUBLIC_IP" ]]; then
    echo "❌ Error: All inputs must be provided."
    exit 1
fi

# Install dependencies
echo "Installing required packages..."
sudo apt update
sudo apt install -y nginx python3 python3-venv python3-pip curl

# Install PM2 globally if not present
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    sudo npm install -g pm2
else
    echo "PM2 already installed."
fi

# App directory setup
APP_DIR="/opt/pm2-log-viewer-${APP_NAME}"
sudo mkdir -p "$APP_DIR"
sudo chown $USER:$USER "$APP_DIR"

cd "$APP_DIR"

# Python venv setup
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install flask

# Generate working app.py
cat > app.py <<EOF
from flask import Flask, render_template_string
import subprocess

app = Flask(__name__)

LOG_FILE_PATH = "${LOG_PATH}"

TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>PM2 Logs Viewer</title>
    <meta http-equiv="refresh" content="5">
    <style>
        body { font-family: monospace; background: #222; color: #eee; padding: 1em; }
        pre { background: #333; padding: 1em; overflow-x: auto; }
        button { margin-top: 1em; padding: 0.5em 1em; }
    </style>
</head>
<body>
    <h1>PM2 Logs (Live Logs)</h1>
    <pre>{{ logs }}</pre>
    <form action="all">
        <button type="submit">View All Logs</button>
    </form>
</body>
</html>
"""

TEMPLATE_ALL = """
<!DOCTYPE html>
<html>
<head>
    <title>PM2 Logs Viewer - All Logs</title>
    <style>
        body { font-family: monospace; background: #222; color: #eee; padding: 1em; }
        pre { background: #333; padding: 1em; overflow-x: auto; }
        a { color: #0cf; }
    </style>
</head>
<body>
    <h1>PM2 Logs (Last 10000 Lines)</h1>
    <pre>{{ logs }}</pre>
    <a href="/">Back to live view</a>
</body>
</html>
"""

def get_last_n_lines(n):
    try:
        output = subprocess.check_output(["tail", f"-n{n}", LOG_FILE_PATH])
        return output.decode(errors="ignore")
    except subprocess.CalledProcessError as e:
        return f"Error reading logs: {e}"

@app.route("/")
def index():
    logs = get_last_n_lines(30)
    return render_template_string(TEMPLATE, logs=logs)

@app.route("/all")
def all_logs():
    logs = get_last_n_lines(10000)
    return render_template_string(TEMPLATE_ALL, logs=logs)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=${APP_PORT}, debug=False)
EOF

# Start the Flask app using PM2
echo "Starting Flask app with PM2..."
pm2 start venv/bin/python --name pm2-log-viewer-${APP_NAME} -- app.py
pm2 save

# Configure Nginx properly
echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/pm2-log-viewer-${APP_NAME} > /dev/null <<NGINX_CONF
server {
    listen 80;

    server_name ${PUBLIC_IP};  # Use the EC2 public IP as the server name

    location /${APP_NAME}/ {
        proxy_pass http://127.0.0.1:${APP_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location = /${APP_NAME} {
        return 301 /${APP_NAME}/;
    }
}
NGINX_CONF

# Enable the new site
sudo ln -sf /etc/nginx/sites-available/pm2-log-viewer-${APP_NAME} /etc/nginx/sites-enabled/pm2-log-viewer-${APP_NAME}

# Optional: Disable default site if needed
# sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx

echo "✅ Setup complete!"
echo "🔗 Access your logs at: http://${PUBLIC_IP}/${APP_NAME}/"
echo "📁 App saved in: ${APP_DIR}"
