<?php
// Set response headers
header('Content-Type: application/json');

// Parse the request method
$request_method = $_SERVER['REQUEST_METHOD'];

// Get URL parameters
$url_params = $_GET;

// Get JSON input (for POST, PUT, DELETE)
$input = json_decode(file_get_contents('php://input'), true);

// Initialize response array
$response = [];

// Handle different request methods
switch ($request_method) {
    case 'GET':
        // Handle GET request
        $response['method'] = 'GET';
        $response['url_params'] = $url_params;
        $response['message'] = 'Handled GET request';
        break;

    case 'POST':
        // Handle POST request
        $response['method'] = 'POST';
        $response['url_params'] = $url_params;
        $response['input'] = $input;
        $response['message'] = 'Handled POST request';
        break;

    case 'PUT':
        // Handle PUT request
        $response['method'] = 'PUT';
        $response['url_params'] = $url_params;
        $response['input'] = $input;
        $response['message'] = 'Handled PUT request';
        break;

    case 'DELETE':
        // Handle DELETE request
        $response['method'] = 'DELETE';
        $response['url_params'] = $url_params;
        $response['input'] = $input;
        $response['message'] = 'Handled DELETE request';
        break;

    default:
        // Handle unknown request method
        http_response_code(405); // Method Not Allowed
        $response['error'] = 'Method Not Allowed';
        break;
}

// Send response
echo json_encode($response);
