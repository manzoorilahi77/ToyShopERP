require('dotenv').config();
const jwt = require('jsonwebtoken');
const fs = require('fs');

const token = jwt.sign({ id: 1, role: 'Owner', branchId: 1 }, process.env.JWT_SECRET || 'fallback_secret', { expiresIn: '1h' });

async function testApi() {
  try {
    // create a dummy file
    fs.writeFileSync('dummy.jpg', 'dummy image data');

    const form = new FormData();
    form.append('name', 'Test Toy With Image');
    form.append('categoryId', '1');
    form.append('price', '150');
    form.append('stock', '20');
    
    // Read file as Blob using fetch API's File
    const fileBuffer = fs.readFileSync('dummy.jpg');
    const fileBlob = new Blob([fileBuffer], { type: 'image/jpeg' });
    form.append('image', fileBlob, 'dummy.jpg');

    const res = await fetch('http://localhost:5000/api/v1/products', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      },
      body: form
    });
    const text = await res.text();
    console.log('Status:', res.status);
    console.log('Response:', text);
  } catch (err) {
    console.error(err);
  }
}
testApi();
