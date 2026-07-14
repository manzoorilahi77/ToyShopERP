const { Product } = require('./src/models');
Product.findAll({ limit: 5 }).then(products => {
  console.log(JSON.stringify(products, null, 2));
  process.exit(0);
}).catch(err => console.error(err));
