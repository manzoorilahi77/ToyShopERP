const bcrypt = require('bcrypt');
const { sequelize, Role, Branch, User, Category, Product } = require('../models');

async function seed() {
  await sequelize.sync({ force: true });
  console.log('Database synced (force).');

  // Roles
  const roles = await Role.bulkCreate([
    { name: 'Super Admin' },
    { name: 'Owner' },
    { name: 'Manager' },
    { name: 'Staff' }
  ]);

  // Branches
  const branch1 = await Branch.create({ name: 'Downtown Store', location: '123 Main St', contact: '555-0101' });

  // Passwords (using the PIN 1234 for testing)
  const hashedPin = await bcrypt.hash('1234', 10);

  // Users
  await User.bulkCreate([
    { name: 'Admin', email: 'admin@test.com', password: hashedPin, roleId: roles[0].id },
    { name: 'Priya Owner', email: 'owner@test.com', password: hashedPin, roleId: roles[1].id, branchId: branch1.id },
    { name: 'Manager Mike', email: 'manager@test.com', password: hashedPin, roleId: roles[2].id, branchId: branch1.id },
    { name: 'Ravi', email: 'ravi@test.com', password: hashedPin, roleId: roles[3].id, branchId: branch1.id },
    { name: 'Anbu', email: 'anbu@test.com', password: hashedPin, roleId: roles[3].id, branchId: branch1.id },
  ]);

  // Categories
  const cat1 = await Category.create({ name: 'Action Figures', icon: 'zap', color: 'bg-red-500' });
  const cat2 = await Category.create({ name: 'Board Games', icon: 'dice-5', color: 'bg-blue-500' });

  // Products
  await Product.bulkCreate([
    { name: 'Superhero Action Figure', categoryId: cat1.id, price: 599, stock: 15, isFavorite: true, image: 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?auto=format&fit=crop&w=300&q=80' },
    { name: 'Monopoly Classic', categoryId: cat2.id, price: 999, stock: 5, isFavorite: true, image: 'https://images.unsplash.com/photo-1611891487122-207578368580?auto=format&fit=crop&w=300&q=80' },
  ]);

  console.log('Seed completed successfully. You can log in using PIN: 1234 for all users.');
  process.exit(0);
}

seed().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
