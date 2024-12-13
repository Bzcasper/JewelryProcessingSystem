# webhook_handler.py

from flask import Flask, request, jsonify
import hmac
import hashlib
import os
import json

app = Flask(__name__)

# Replace with your Cloudinary webhook secret if configured
WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', 'your_webhook_secret')

def verify_signature(data, signature):
    computed_signature = hmac.new(
        WEBHOOK_SECRET.encode('utf-8'),
        msg=json.dumps(data, separators=(',', ':'), sort_keys=True).encode('utf-8'),
        digestmod=hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(computed_signature, signature)

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    signature = request.headers.get('X-Webhook-Signature')
    data = request.get_json()

    if not signature or not verify_signature(data, signature):
        return jsonify({'error': 'Invalid signature'}), 400

    # Process the webhook event
    event_type = data.get('event')
    resource_type = data.get('resource_type')
    public_id = data.get('public_id')

    # Example: Log the event
    app.logger.info(f"Received event: {event_type} for resource: {public_id}")

    # TODO: Add your custom processing logic here

    return jsonify({'status': 'success'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
