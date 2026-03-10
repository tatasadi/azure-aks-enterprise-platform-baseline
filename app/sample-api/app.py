"""
Sample API for AKS Enterprise Platform Baseline
Demonstrates Workload Identity and Key Vault integration
"""

import os
import socket
import time
from datetime import datetime
from flask import Flask, jsonify, request
from pathlib import Path
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

REQUEST_IN_PROGRESS = Gauge(
    'http_requests_in_progress',
    'HTTP requests currently in progress',
    ['method', 'endpoint']
)

# Configuration
VERSION = os.getenv('APP_VERSION', 'v1.0.0')
SECRET_PATH = os.getenv('SECRET_PATH', '/mnt/secrets')


# Prometheus hooks
@app.before_request
def before_request():
    """Track request start time and increment in-progress gauge"""
    request.start_time = time.time()
    REQUEST_IN_PROGRESS.labels(
        method=request.method,
        endpoint=request.path
    ).inc()


@app.after_request
def after_request(response):
    """Track request completion, duration, and decrement in-progress gauge"""
    if hasattr(request, 'start_time'):
        # Calculate request duration
        duration = time.time() - request.start_time

        # Record metrics
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.path
        ).observe(duration)

        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.path,
            status=response.status_code
        ).inc()

        # Decrement in-progress gauge
        REQUEST_IN_PROGRESS.labels(
            method=request.method,
            endpoint=request.path
        ).dec()

    return response


@app.route('/metrics', methods=['GET'])
def metrics():
    """
    Prometheus metrics endpoint
    Returns metrics in Prometheus exposition format
    """
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/health', methods=['GET'])
def health():
    """
    Health check endpoint
    Returns 200 OK if the application is running
    """
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': VERSION
    }), 200


@app.route('/info', methods=['GET'])
def info():
    """
    Information endpoint
    Returns pod metadata and environment information
    """
    return jsonify({
        'application': 'sample-api',
        'version': VERSION,
        'hostname': socket.gethostname(),
        'namespace': os.getenv('POD_NAMESPACE', 'unknown'),
        'pod_name': os.getenv('POD_NAME', 'unknown'),
        'node_name': os.getenv('NODE_NAME', 'unknown'),
        'service_account': os.getenv('SERVICE_ACCOUNT', 'unknown'),
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/secret', methods=['GET'])
def secret():
    """
    Secret endpoint
    Reads and returns secrets mounted from Azure Key Vault via CSI driver
    """
    try:
        secrets_dir = Path(SECRET_PATH)

        # Check if secrets directory exists
        if not secrets_dir.exists():
            return jsonify({
                'status': 'error',
                'message': f'Secrets directory not found: {SECRET_PATH}',
                'hint': 'Secrets are mounted via CSI driver at pod startup'
            }), 404

        # List available secrets
        secret_files = [f.name for f in secrets_dir.iterdir() if f.is_file()]

        if not secret_files:
            return jsonify({
                'status': 'warning',
                'message': 'Secrets directory exists but no secrets found',
                'path': SECRET_PATH
            }), 200

        # Read the first secret (db-connection-string)
        secrets_data = {}
        for secret_file in secret_files:
            secret_file_path = secrets_dir / secret_file
            try:
                with open(secret_file_path, 'r') as f:
                    # Only show first 20 characters for security
                    secret_value = f.read().strip()
                    secrets_data[secret_file] = {
                        'exists': True,
                        'preview': secret_value[:20] + '...' if len(secret_value) > 20 else secret_value,
                        'length': len(secret_value)
                    }
            except Exception as e:
                secrets_data[secret_file] = {
                    'exists': True,
                    'error': str(e)
                }

        return jsonify({
            'status': 'success',
            'message': 'Secrets retrieved from Azure Key Vault via CSI driver',
            'path': SECRET_PATH,
            'secrets': secrets_data,
            'timestamp': datetime.utcnow().isoformat()
        }), 200

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e),
            'path': SECRET_PATH
        }), 500


@app.route('/', methods=['GET'])
def root():
    """
    Root endpoint
    Returns basic API information and available endpoints
    """
    return jsonify({
        'name': 'AKS Platform Sample API',
        'version': VERSION,
        'description': 'Demo application for Azure AKS Enterprise Platform Baseline',
        'endpoints': {
            '/': 'This endpoint - API information',
            '/health': 'Health check endpoint',
            '/info': 'Pod and environment information',
            '/secret': 'Read secrets from Azure Key Vault via CSI driver',
            '/metrics': 'Prometheus metrics endpoint'
        },
        'features': [
            'Azure Workload Identity integration',
            'Azure Key Vault CSI Driver',
            'Kubernetes metadata exposure',
            'Health checks for liveness/readiness probes',
            'Prometheus metrics instrumentation'
        ]
    }), 200


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'status': 'error',
        'message': 'Endpoint not found',
        'path': os.getenv('PATH_INFO', 'unknown')
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({
        'status': 'error',
        'message': 'Internal server error',
        'error': str(error)
    }), 500


if __name__ == '__main__':
    # Run the Flask application
    # In production, use a WSGI server like Gunicorn
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
