const sequelize = require('./src/config/database');
const { Role } = require('./src/models');

async function fixRoles() {
  await sequelize.authenticate();
  
  const deleted = await Role.destroy({ where: { name: 'Online Sales' } });
  
  if (deleted) {
    console.log("Deleted 'Online Sales' role.");
  } else {
    console.log("'Online Sales' role not found.");
  }
  process.exit(0);
}
fixRoles().catch(err => { console.error(err); process.exit(1); });
