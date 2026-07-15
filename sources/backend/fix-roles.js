const sequelize = require('./src/config/database');
const { Role } = require('./src/models');

async function fixRoles() {
  await sequelize.authenticate();
  
  const [role, created] = await Role.findOrCreate({
    where: { name: 'Online Sales' },
    defaults: { name: 'Online Sales' }
  });
  
  if (created) {
    console.log("Added 'Online Sales' role with ID:", role.id);
  } else {
    console.log("'Online Sales' role already exists with ID:", role.id);
  }
  process.exit(0);
}
fixRoles().catch(err => { console.error(err); process.exit(1); });
