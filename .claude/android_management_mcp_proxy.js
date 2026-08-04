const { spawn } = require('child_process');
const fs = require('fs');
const https = require('https');
const path = require('path');

function getAccessToken() {
  return new Promise((resolve, reject) => {
    try {
      const appData = process.env.APPDATA || path.join(process.env.USERPROFILE || 'C:\\Users\\syedr', 'AppData', 'Roaming');
      const adcPath = path.join(appData, 'gcloud', 'application_default_credentials.json');
      
      if (!fs.existsSync(adcPath)) {
        throw new Error(`ADC file not found at ${adcPath}`);
      }
      const creds = JSON.parse(fs.readFileSync(adcPath, 'utf8'));
      if (creds.type !== 'authorized_user') {
        throw new Error(`Unsupported credential type: ${creds.type}`);
      }

      const postData = JSON.stringify({
        client_id: creds.client_id,
        client_secret: creds.client_secret,
        refresh_token: creds.refresh_token,
        grant_type: 'refresh_token'
      });

      const req = https.request('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        }
      }, (res) => {
        let body = '';
        res.on('data', (chunk) => body += chunk);
        res.on('end', () => {
          try {
            const data = JSON.parse(body);
            if (data.access_token) {
              resolve(data.access_token);
            } else {
              reject(new Error(`Failed to refresh token: ${body}`));
            }
          } catch (e) {
            reject(e);
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    } catch (error) {
      reject(error);
    }
  });
}

async function main() {
  try {
    const token = await getAccessToken();
    
    // Start mcp-remote bridge connecting to the Android Management API MCP server
    const child = spawn('npx', [
      '-y',
      'mcp-remote',
      'https://androidmanagement.googleapis.com/mcp',
      '--header',
      `"Authorization: Bearer ${token}"`,
      '--header',
      '"x-goog-user-project: awaken-27f39"'
    ], {
      stdio: ['pipe', 'pipe', 'inherit'],
      shell: true // Required on Windows for npx execution
    });

    // Pipe stdin from Claude Desktop to the bridge
    process.stdin.pipe(child.stdin);

    // Pipe stdout from the bridge back to Claude Desktop
    child.stdout.pipe(process.stdout);

    // Handle termination
    child.on('exit', (code, signal) => {
      process.exit(code !== null ? code : 1);
    });

    process.on('SIGINT', () => child.kill('SIGINT'));
    process.on('SIGTERM', () => child.kill('SIGTERM'));

  } catch (error) {
    console.error('Failed to start Android Management MCP Proxy:', error);
    process.exit(1);
  }
}

main();
