require('dotenv').config();
const jwt = require('jsonwebtoken');

const token = jwt.sign({ id: 2, role: 'Staff', branchId: 1 }, process.env.JWT_SECRET || 'fallback_secret', { expiresIn: '1h' });

async function testApi() {
  try {
    const res = await fetch('http://localhost:5000/api/v1/products', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    const text = await res.text();
    console.log('Status:', res.status);
    console.log('Response:', text);
  } catch (err) {
    console.error(err);
  }
}
testApi();
