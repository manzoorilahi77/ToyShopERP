const sequelize = require('./src/config/database');
const { User } = require('./src/models');
const bcrypt = require('bcrypt');

async function test() {
  await sequelize.authenticate();
  try {
      const hashedPassword = await bcrypt.hash("1234", 10);
      const user = await User.create({
        name: "Test2",
        email: "test2@example.com",
        password: hashedPassword,
        roleId: 4,
        branchId: NaN
      });
      console.log("Success");
  } catch (e) {
      console.error("ERROR:", e.message);
  }
  process.exit(0);
}
test().catch(err => { console.error(err); process.exit(1); });
