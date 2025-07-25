# PM2 Log Viewer Setup

This project provides a simple **PM2 Log Viewer** powered by **Flask**. It allows you to view PM2 logs through a browser-based interface. The logs can be viewed live or you can access the last 10,000 lines of the logs. 

The log viewer can be easily installed on an **EC2 instance** (or any other Linux server) via a simple installation script.

## Features
- **Flask-based Web Application** to display PM2 logs
- **Real-time log display** with the ability to view up to the last 10,000 log lines
- Configured with **Nginx** for reverse proxying
- **PM2** is used to manage the Flask app

## Installation

You can quickly install the PM2 log viewer on your server with just one command. This script will:

- Install required packages like **Python3**, **Nginx**, and **PM2**
- Setup a **Flask** application to view the PM2 logs
- Configure **Nginx** to proxy requests to the Flask application

### To install the PM2 Log Viewer:

Run the following command on your EC2 instance or server:

```bash
curl -sSL https://raw.githubusercontent.com/jaideepp247/PM2-Logs-Viewer-Setup/main/install-log-viewer.sh | bash
