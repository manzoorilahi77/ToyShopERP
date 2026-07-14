const { Product, Category } = require('./src/models');

async function test() {
  try {
    const products = await Product.findAll({
      include: [{ model: Category, as: 'category' }]
    });
    console.log('Success:', products.length);
  } catch (error) {
    console.error('Error details:', error);
  }
}
test();
