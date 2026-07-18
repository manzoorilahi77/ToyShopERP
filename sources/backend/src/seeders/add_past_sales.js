const { sequelize, Sale, SaleItem, Product, User, Branch } = require('../models');

async function seedPastSales() {
  try {
    const branch = await Branch.findOne();
    const user = await User.findOne({ where: { name: 'Priya Owner' } }) || await User.findOne();
    const products = await Product.findAll({ limit: 2 });
    
    if (!branch || !user || products.length === 0) {
      console.log('Ensure you have a branch, user, and products before running this.');
      process.exit(1);
    }
    
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    const dayBefore = new Date(today);
    dayBefore.setDate(dayBefore.getDate() - 2);

    const dates = [yesterday, yesterday, dayBefore, dayBefore];
    
    for (let i = 0; i < dates.length; i++) {
      const date = dates[i];
      const product = products[i % products.length];
      
      const quantity = Math.floor(Math.random() * 3) + 1;
      const unitPrice = product.price;
      const rate = 18; // default gst
      
      const itemTotal = unitPrice * quantity;
      const itemTaxableAmount = itemTotal;
      const itemGstAmount = itemTotal * (rate / 100);
      const itemCgst = itemGstAmount / 2;
      const itemSgst = itemGstAmount / 2;
      const totalAmount = itemTotal + itemGstAmount;
      
      const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      const invoiceNumber = `INV-${dateStr}-${randomSuffix}`;
      
      const sale = await Sale.create({
        invoiceNumber,
        branchId: branch.id,
        userId: user.id,
        subtotal: itemTaxableAmount,
        cgst: itemCgst,
        sgst: itemSgst,
        igst: 0,
        taxableAmount: itemTaxableAmount,
        totalAmount,
        paymentMethod: 'cash',
        status: 'completed',
        createdAt: date,
        updatedAt: date
      });
      
      await SaleItem.create({
        productId: product.id,
        saleId: sale.id,
        quantity,
        unitPrice,
        subTotal: itemTotal,
        gstPercent: rate,
        gstAmount: itemGstAmount,
        taxableAmount: itemTaxableAmount,
        createdAt: date,
        updatedAt: date
      });
    }
    
    console.log('Past sales added successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error adding past sales', error);
    process.exit(1);
  }
}

seedPastSales();
