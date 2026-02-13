const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('📝 PostgreSQL Password Setup\n');
console.log('This will update your .env file with the correct PostgreSQL password.\n');

rl.question('Enter your PostgreSQL password: ', (password) => {
  const envPath = path.join(__dirname, '.env');
  
  try {
    let envContent = fs.readFileSync(envPath, 'utf8');
    
    // Replace the password line
    envContent = envContent.replace(
      /DB_PASSWORD=.*/,
      `DB_PASSWORD=${password}`
    );
    
    fs.writeFileSync(envPath, envContent);
    
    console.log('\n✅ Password updated successfully in .env file!');
    console.log('\nNow try starting the server again:');
    console.log('   npm run dev\n');
    
  } catch (error) {
    console.error('❌ Error updating .env file:', error.message);
  }
  
  rl.close();
});
