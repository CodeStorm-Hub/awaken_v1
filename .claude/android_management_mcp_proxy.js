const { spawn, execSync } = require('child_process');

try {
  // Get fresh access token from gcloud Application Default Credentials (ADC)
  const token = execSync('gcloud auth application-default print-access-token', { encoding: 'utf8' }).trim();
  
  // Start mcp-remote bridge connecting to the Android Management API MCP server
  const child = spawn('npx', [
    '-y',
    '@modelcontextprotocol/inspector',
    'mcp-remote',
    'https://androidmanagement.googleapis.com/mcp',
    '--header',
    `Authorization: Bearer ${token}`
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
