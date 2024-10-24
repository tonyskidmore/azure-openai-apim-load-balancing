""" APIM Request Example with Backend Tracking """
import json
import os
import uuid
from typing import Dict

import requests
from dotenv import load_dotenv


def make_azure_openai_request(api_management_gateway_url,
                              api_management_subscription_key):
    """
    Makes a request to the Azure OpenAI API using the provided API management
    gateway URL and subscription key. Tracks backend routing information.

    Args:
        api_management_gateway_url (str):
            The URL of the API management gateway.
        api_management_subscription_key (str):
            The subscription key for the API management.

    Returns:
        Tuple[Dict, Dict, Dict]: The response data, rate limits, and routing info
    """
    # Define the model and API version
    model = "gpt-35-turbo"
    api_version = "2024-03-01-preview"

    # Construct the completions endpoint
    completions_endpoint = (
        f"{api_management_gateway_url}/openai/"
        f"deployments/{model}/chat/completions"
        f"?api-version={api_version}"
    )

    # Generate request tracking ID
    request_id = str(uuid.uuid4())

    # Define the request headers
    request_headers = {
        "Ocp-Apim-Subscription-Key": api_management_subscription_key,
        "Content-Type": "application/json",
        "x-ms-client-request-id": request_id,
        "x-correlation-id": request_id,
        # Add header to track which backend was used
        "x-request-backend": "unknown"
    }

    # Define the request body
    request_body = {
        "messages": [
            {
                "role": "system",
                "content": """
                You are a helpful AI assistant. You always try to provide
                accurate answers or follow up with another question if not.
                """
            },
            {
                "role": "user",
                "content": "What is the best way to get to London from Berlin?"
            }
        ],
        "max_tokens": 200,
        "temperature": 0.7,
        "top_p": 0.95,
        "frequency_penalty": 0,
        "presence_penalty": 0
    }

    try:
        print(f"Posting request to: {completions_endpoint}")
        print(f"Request ID: {request_id}")

        # Make the API request
        response = requests.post(
            completions_endpoint,
            headers=request_headers,
            json=request_body,
            timeout=10
        )

        # Raise an exception for bad status codes
        response.raise_for_status()

        # Extract rate limit headers
        rate_limits = {
            'x-ratelimit-remaining-requests': response.headers.get(
                'x-ratelimit-remaining-requests'
            ),
            'x-ratelimit-remaining-tokens': response.headers.get(
                'x-ratelimit-remaining-tokens'
            ),
            'x-ratelimit-reset-requests': response.headers.get(
                'x-ratelimit-reset-requests'
            ),
            'x-ratelimit-reset-tokens': response.headers.get(
                'x-ratelimit-reset-tokens'
            ),
            'x-ratelimit-limit-requests': response.headers.get(
                'x-ratelimit-limit-requests'
            ),
            'x-ratelimit-limit-tokens': response.headers.get(
                'x-ratelimit-limit-tokens'
            ),
        }

        # Extract routing information
        routing = {
            'request_id': request_id,
            'backend_service': (
                'OpenAIUKS' if response.headers.get('x-ms-region') == 'UK South'
                else 'OpenAIWUS' if response.headers.get('x-ms-region') == 'West US'
                else 'Unknown'
            ),
            'x-ms-routing-name': response.headers.get('x-ms-routing-name'),
            'x-azure-ref': response.headers.get('x-azure-ref'),
            'x-cache': response.headers.get('x-cache'),
            'x-ms-region': response.headers.get('x-ms-region'),
            'x-ms-client-request-id': response.headers.get(
                'x-ms-client-request-id'
            ),
            'x-ms-request-id': response.headers.get('x-ms-request-id'),
            'x-test': response.headers.get('x-test'),
            'x-backend-service': response.headers.get('x-backend-service'),
            'x-correlation-id': response.headers.get('x-correlation-id'),
            'retry_count': response.headers.get('x-retry-count', '0'),
            # New timing and cache information
            'request_time': response.headers.get('x-request-time'),
            'request_duration_ms': response.headers.get('x-request-duration'),
            'cache_status': response.headers.get('x-cache-status')
        }

        return response.json(), rate_limits, routing

    except requests.exceptions.RequestException as e:
        print(f"Error making request: {e}")
        return None, None, None


def print_routing_info(routing_info: Dict):
    """
    Helper function to print routing information in a formatted way,
    specifically highlighting the backend service used.
    """
    if routing_info:
        print("\nRouting Information:")
        print(json.dumps(routing_info, indent=2))

        print("\nBackend Service Details:")
        print(f"Request ID: "
              f"{routing_info.get('request_id','Unknown')}")
        print(f"Backend: "
              f"{routing_info.get('backend_service', 'Unknown')}")
        print(f"Region: "
              f"{routing_info.get('x-ms-region', 'Unknown')}")
        print(f"Correlation ID: "
              f"{routing_info.get('x-correlation-id', 'Unknown')}")
        print(f"Retry Count: "
              f"{routing_info.get('retry_count', '0')}")
        print(f"Test Header: "
              f"{routing_info.get('x-test', '0')}")

        print("\nTiming and Cache Information:")
        print(f"Request Time (UTC): "
              f"{routing_info.get('request_time', 'Unknown')}")
        print(f"Request Duration: "
              f"{routing_info.get('request_duration_ms', 'Unknown')} ms")
        print(f"Cache Status: "
              f"{routing_info.get('cache_status', 'Unknown')}")
        print(f"Correlation ID: "
              f"{routing_info.get('x-correlation-id', 'Unknown')}")
        print(f"Backend Service: "
              f"{routing_info.get('x-backend-service', 'Unknown')}")


def check_rate_limits(rate_limits: Dict) -> bool:
    """
    Helper function to check if we're close to rate limits
    and dump rate limit info as JSON.
    Returns True if we're running low on requests or tokens
    """
    if rate_limits is None:
        return False

    # First, dump all rate limit headers as JSON
    print("\nComplete Rate Limit Headers:")
    print(json.dumps(rate_limits, indent=2))

    remaining_requests = rate_limits.get('x-ratelimit-remaining-requests')
    remaining_tokens = rate_limits.get('x-ratelimit-remaining-tokens')

    if remaining_requests and int(remaining_requests) < 10:
        print(f"Warning: Only {remaining_requests} requests remaining!")
        return True

    if remaining_tokens and int(remaining_tokens) < 1000:
        print(f"Warning: Only {remaining_tokens} tokens remaining!")
        return True

    return False


# Example usage:
if __name__ == "__main__":

    # Load environment variables
    load_dotenv()

    # only used to send repeated requests for testing
    REPEAT = 1

    API_MANAGEMENT_GATEWAY_URL = os.environ.get(
                                    "API_MANAGEMENT_GATEWAY_URL"
                                )
    API_MANAGEMENT_SUBSCRIPTION_KEY = os.environ.get(
                                        "API_MANAGEMENT_SUBSCRIPTION_KEY"
                                    )

    for _ in range(REPEAT):
        response_data, openai_rate_limits, routing_info = (
            make_azure_openai_request(
                API_MANAGEMENT_GATEWAY_URL,
                API_MANAGEMENT_SUBSCRIPTION_KEY
            )
        )

        if response_data:
            print("\nAPI Response:")
            print(json.dumps(response_data, indent=2))

            print("\nRate Limit Information:")
            check_rate_limits(openai_rate_limits)

            print_routing_info(routing_info)
