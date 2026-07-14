async function testOptions() {
  try {
    const res = await fetch('http://localhost:5000/api/v1/products', {
      method: 'OPTIONS',
      headers: {
        'Origin': 'http://localhost:5173',
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'Authorization, Content-Type'
      }
    });
    console.log('OPTIONS Status:', res.status);
    let headers = '';
    res.headers.forEach((v, k) => headers += `${k}: ${v}\n`);
    console.log('OPTIONS Headers:\n' + headers);
  } catch (err) {
    console.error(err);
  }
}
testOptions();
