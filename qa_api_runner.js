const fs = require('fs');

const BASE_URL = 'http://localhost:5000/api/v1';

const results = [];
let token = null;

// Endpoints to test based on route files
const testEndpoints = [
    { method: 'POST', path: '/auth/login', body: { email: 'admin@test.com', password: 'password123' }, name: 'Owner Login' },
    { method: 'GET', path: '/dashboard/owner', requiresAuth: true, name: 'Get Owner Dashboard' },
    { method: 'GET', path: '/products', requiresAuth: true, name: 'List Products' },
    { method: 'POST', path: '/products', requiresAuth: true, body: { name: 'TEST_QA_Product', sku: 'TEST-SKU-1', price: 100, stock: 10, category_id: 1, branch_id: 1 }, name: 'Create Product' },
    { method: 'GET', path: '/categories', requiresAuth: true, name: 'List Categories' },
    { method: 'POST', path: '/categories', requiresAuth: true, body: { name: 'TEST_QA_Category', description: 'Test category' }, name: 'Create Category' },
    { method: 'GET', path: '/branches', requiresAuth: true, name: 'List Branches' },
    { method: 'GET', path: '/users', requiresAuth: true, name: 'List Users' },
    { method: 'GET', path: '/customers', requiresAuth: true, name: 'List Customers' },
    { method: 'GET', path: '/suppliers', requiresAuth: true, name: 'List Suppliers' },
    { method: 'GET', path: '/sales', requiresAuth: true, name: 'List Sales' },
    { method: 'POST', path: '/sales', requiresAuth: true, body: { customer_id: 1, branch_id: 1, total_amount: 118, gst_amount: 18, payment_method: 'CASH', items: [{ product_id: 1, quantity: 1, price: 100 }] }, name: 'Create Sale' },
    { method: 'GET', path: '/purchases', requiresAuth: true, name: 'List Purchases' },
    { method: 'GET', path: '/gst/reports', requiresAuth: true, name: 'Get GST Reports' },
    { method: 'GET', path: '/notifications', requiresAuth: true, name: 'List Notifications' },
    { method: 'POST', path: '/notifications', requiresAuth: true, body: { title: 'TEST_QA_Alert', message: 'This is a test alert', type: 'INFO', for_role: 'OWNER' }, name: 'Create Notification' },
    { method: 'GET', path: '/cart', requiresAuth: true, name: 'Get Cart' },
    { method: 'GET', path: '/online-orders', requiresAuth: true, name: 'List Online Orders' },
    // Negative tests
    { method: 'POST', path: '/auth/login', body: { email: 'invalid@test.com', password: 'wrong' }, name: 'Login Invalid Credentials' },
    { method: 'GET', path: '/dashboard/owner', requiresAuth: false, name: 'Get Dashboard Unauthorized (No Token)' },
    { method: 'POST', path: '/products', requiresAuth: true, body: { name: '' }, name: 'Create Product Missing Fields' }
];

async function runTests() {
    console.log('Starting API Test Execution...');
    
    for (const ep of testEndpoints) {
        let headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        };

        if (ep.requiresAuth && token) {
            headers['Authorization'] = `Bearer ${token}`;
        } else if (ep.requiresAuth && !token) {
            // For the unauthorized test case, explicitly remove token
            if (ep.name.includes('Unauthorized')) {
                // leave token out
            }
        }

        const options = {
            method: ep.method,
            headers
        };

        if (ep.body) {
            options.body = JSON.stringify(ep.body);
        }

        const start = Date.now();
        let status = 500;
        let responseBody = null;
        let isWorking = false;
        let errorMessage = '';

        try {
            const res = await fetch(`${BASE_URL}${ep.path}`, options);
            status = res.status;
            
            try {
                responseBody = await res.json();
            } catch(e) {
                responseBody = await res.text();
            }
            
            // Extract token from successful login to use for subsequent requests
            if (ep.path === '/auth/login' && status === 200 && responseBody && responseBody.data && responseBody.data.accessToken && !ep.name.includes('Invalid')) {
                token = responseBody.data.accessToken;
            }

            // Determine if the test "Passed" or "Failed" based on expectation
            if (ep.name.includes('Invalid') || ep.name.includes('Unauthorized') || ep.name.includes('Missing')) {
                // We expect an error code (400, 401, 403)
                isWorking = (status >= 400 && status < 500);
            } else {
                // We expect success (200, 201)
                isWorking = (status >= 200 && status < 300);
            }

        } catch (error) {
            errorMessage = error.message;
            isWorking = false;
        }

        const duration = Date.now() - start;

        const result = {
            name: ep.name,
            method: ep.method,
            path: `${ep.path}`,
            requiresAuth: !!ep.requiresAuth,
            status: status,
            duration: `${duration} ms`,
            isWorking: isWorking ? 'Yes' : 'No',
            passFail: isWorking ? 'PASS' : 'FAIL',
            error: isWorking ? '' : errorMessage || JSON.stringify(responseBody)
        };

        console.log(`[${result.passFail}] ${result.method} ${ep.path} - ${status} (${duration}ms)`);
        results.push(result);
    }

    fs.writeFileSync('qa_api_results.json', JSON.stringify(results, null, 2));
    console.log(`Finished executing ${results.length} API endpoints. Results saved to qa_api_results.json`);
}

runTests();
