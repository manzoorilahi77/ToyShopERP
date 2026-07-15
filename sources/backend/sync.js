const { sequelize } = require('./src/models');
async function syncDb() {
  await sequelize.sync({ alter: true });
  console.log('Database synced successfully');
  process.exit(0);
}
syncDb();
