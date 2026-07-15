const sequelize = require('./src/config/database');
const { Role, Branch } = require('./src/models');

async function test() {
  await sequelize.authenticate();
  const roles = await Role.findAll();
  console.log("Roles:", roles.map(r => r.toJSON()));
  const branches = await Branch.findAll();
  console.log("Branches:", branches.map(b => b.toJSON()));
  process.exit(0);
}
test().catch(err => { console.error(err); process.exit(1); });
