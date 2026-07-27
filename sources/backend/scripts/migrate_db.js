const mysql = require('mysql2/promise');

// Configuration - Local (Source)
const localDbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'MdSaajid0005@',
  database: 'toyshoperp',
  port: 3306,
  multipleStatements: true
};

// Configuration - Development (Target)
const devDbConfig = {
  host: process.env.DEV_DB_HOST || 'WAITING_FOR_HOST', // <--- WE NEED THIS
  user: 'aspirfxc_toys_user',
  password: 'toys@CZ73KDb',
  database: 'aspirfxc_toys_db',
  port: 3306,
  multipleStatements: true
};

async function migrateDatabase() {
  if (devDbConfig.host === 'WAITING_FOR_HOST') {
    console.error('Error: Please set DEV_DB_HOST environment variable before running this script.');
    process.exit(1);
  }

  let localConn, devConn;
  const report = [];

  try {
    console.log('Connecting to Local Database...');
    localConn = await mysql.createConnection(localDbConfig);
    console.log('Connecting to Development Database...');
    devConn = await mysql.createConnection(devDbConfig);

    console.log('Fetching tables from Local Database...');
    const [tablesRow] = await localConn.query('SHOW TABLES');
    const tableNames = tablesRow.map(row => Object.values(row)[0]);

    console.log(`Found ${tableNames.length} tables to migrate.`);

    // Disable foreign key checks on target for schema and data migration
    await devConn.query('SET FOREIGN_KEY_CHECKS = 0;');

    for (const tableName of tableNames) {
      console.log(`\nProcessing table: ${tableName}`);
      
      // 1. Schema Migration
      const [createTableData] = await localConn.query(`SHOW CREATE TABLE \`${tableName}\``);
      let createTableSql = createTableData[0]['Create Table'];
      
      try {
        // Change to IF NOT EXISTS for safety
        createTableSql = createTableSql.replace('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS');
        await devConn.query(createTableSql);
      } catch (err) {
        console.error(`Error creating table ${tableName}:`, err.message);
      }

      // 2. Data Migration
      const [localData] = await localConn.query(`SELECT * FROM \`${tableName}\``);
      const localRowsCount = localData.length;
      let devRowsCount = 0;
      let status = '✅ PASS';

      if (localRowsCount > 0) {
        console.log(`- Found ${localRowsCount} records to migrate.`);
        // Batch insert
        const batchSize = 100;
        for (let i = 0; i < localRowsCount; i += batchSize) {
          const batch = localData.slice(i, i + batchSize);
          const keys = Object.keys(batch[0]);
          const columns = keys.map(k => `\`${k}\``).join(', ');
          
          const values = batch.map(row => {
            return keys.map(k => {
              const val = row[k];
              if (val === null) return 'NULL';
              if (val instanceof Date) return localConn.escape(val);
              if (typeof val === 'object') return localConn.escape(JSON.stringify(val));
              return localConn.escape(val);
            }).join(', ');
          });

          const valuesSql = values.map(v => `(${v})`).join(', ');
          
          // Use INSERT IGNORE to prevent duplicate records
          const insertSql = `INSERT IGNORE INTO \`${tableName}\` (${columns}) VALUES ${valuesSql}`;
          
          try {
            await devConn.query(insertSql);
          } catch (insertErr) {
            console.error(`- Error inserting batch into ${tableName}:`, insertErr.message);
            status = '❌ FAIL';
          }
        }
      }

      // 3. Verification
      const [devDataCount] = await devConn.query(`SELECT COUNT(*) as count FROM \`${tableName}\``);
      devRowsCount = devDataCount[0].count;

      report.push({
        Table: tableName,
        LocalRows: localRowsCount,
        DevelopmentRows: devRowsCount,
        Status: (localRowsCount === devRowsCount || (devRowsCount >= localRowsCount)) ? '✅ PASS' : '❌ FAIL'
      });
    }

    // Re-enable foreign key checks
    await devConn.query('SET FOREIGN_KEY_CHECKS = 1;');

    console.log('\n--- Final Verification Report ---');
    console.table(report);

  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    if (localConn) await localConn.end();
    if (devConn) await devConn.end();
  }
}

migrateDatabase();
