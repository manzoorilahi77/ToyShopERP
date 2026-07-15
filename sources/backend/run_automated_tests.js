require('dotenv').config();
const fs = require('fs');
const path = require('path');
const http = require('http');

const { User, Role } = require('./src/models');
const { generateAccessToken } = require('./src/utils/jwt');

const PORT = process.env.PORT || 5000;

const results = {
  modulesTested: 0,
  totalTests: 0,
  passed: 0,
  failed: 0,
  tests: []
};

function addResult(module, feature, method, endpoint, status, expectedCode, actualCode, latency, remarks, responseBody) {
  const passed = expectedCode === actualCode;
  results.tests.push({
    id: `TC_${module.toUpperCase()}_${String(results.totalTests + 1).padStart(3, '0')}`,
    module,
    feature,
    method,
    endpoint,
    expectedCode,
    actualCode,
    status: passed ? 'Pass' : 'Fail',
    latency,
    remarks,
    responseBody: responseBody ? responseBody.substring(0, 100) : ''
  });
  results.totalTests++;
  if (passed) results.passed++;
  else results.failed++;
}

async function makeRequest(method, endpoint, token, body = null) {
  return new Promise((resolve) => {
    const start = Date.now();
    const options = {
      hostname: 'localhost',
      port: PORT,
      path: `/api/v1${endpoint}`,
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          body: data,
          latency: Date.now() - start
        });
      });
    });

    req.on('error', (error) => {
      resolve({
        statusCode: 500,
        body: String(error),
        latency: Date.now() - start
      });
    });

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  try {
    console.log("Starting QA Test Execution...");
    
    // 1. Get Admin User and Token
    const adminUser = await User.findOne({ where: { email: 'admin@test.com' }, include: [{ model: Role, as: 'role' }] });
    if (!adminUser) throw new Error("Admin user not found. Cannot proceed with tests.");
    const token = generateAccessToken(adminUser);

    console.log("Authenticated as Admin. Proceeding with endpoints testing...");

    const endpointsToTest = [
      { module: 'Dashboard', feature: 'Dashboard Overview', method: 'GET', endpoint: '/dashboard/overview?period=month' },
      { module: 'Dashboard', feature: 'Recent Activities', method: 'GET', endpoint: '/dashboard/recent-activities' },
      { module: 'Products', feature: 'List Products', method: 'GET', endpoint: '/products' },
      { module: 'Products', feature: 'Get Low Stock', method: 'GET', endpoint: '/products/low-stock' },
      { module: 'Categories', feature: 'List Categories', method: 'GET', endpoint: '/categories' },
      { module: 'Branches', feature: 'List Branches', method: 'GET', endpoint: '/branches' },
      { module: 'Sales', feature: 'List Sales', method: 'GET', endpoint: '/sales' },
      { module: 'Purchases', feature: 'List Purchases', method: 'GET', endpoint: '/purchases' },
      { module: 'Suppliers', feature: 'List Suppliers', method: 'GET', endpoint: '/suppliers' },
      { module: 'GST', feature: 'Get GST Registrations', method: 'GET', endpoint: '/gst-registrations' },
      { module: 'Users', feature: 'List Users', method: 'GET', endpoint: '/users' },
      { module: 'Notifications', feature: 'List Notifications', method: 'GET', endpoint: '/notifications' }
    ];

    results.modulesTested = new Set(endpointsToTest.map(e => e.module)).size;

    for (const ep of endpointsToTest) {
      console.log(`Testing ${ep.method} /api/v1${ep.endpoint}...`);
      const res = await makeRequest(ep.method, ep.endpoint, token);
      addResult(ep.module, ep.feature, ep.method, ep.endpoint, 'Executed', 200, res.statusCode, res.latency, res.statusCode === 200 ? 'Successfully fetched' : 'Failed to fetch', res.body);
    }

    // Negative tests
    console.log("Testing Unauthorized Access...");
    const unauthRes = await makeRequest('GET', '/users', 'invalid_token');
    addResult('Security', 'Unauthorized Access Protection', 'GET', '/users', 'Executed', 401, unauthRes.statusCode, unauthRes.latency, unauthRes.statusCode === 401 ? 'Blocked unauthorized request' : 'Security risk: allowed invalid token', unauthRes.body);

    console.log("Testing Not Found Endpoint...");
    const notFoundRes = await makeRequest('GET', '/invalid-endpoint', token);
    addResult('Error Handling', '404 Handling', 'GET', '/invalid-endpoint', 'Executed', 404, notFoundRes.statusCode, notFoundRes.latency, 'Handled missing route gracefully', notFoundRes.body);

    fs.writeFileSync(path.join(__dirname, 'qa_results.json'), JSON.stringify(results, null, 2));
    console.log("Test execution completed. Results saved to qa_results.json");
    process.exit(0);

  } catch (error) {
    console.error("Test execution failed:", error);
    process.exit(1);
  }
}

runTests();
