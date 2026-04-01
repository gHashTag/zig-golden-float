#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');
const child_process = require('child_process');

const REPO = 'https://github.com/gHashTag/zig-golden-float';
const PLATFORMS = {
  'linux-x64': { os: 'linux', cpu: 'x64', artifact: 'golden-float-x86_64-linux.tar.gz' },
  'linux-arm64': { os: 'linux', cpu: 'arm64', artifact: 'golden-float-aarch64-linux.tar.gz' },
  'darwin-x64': { os: 'darwin', cpu: 'x64', artifact: 'golden-float-x86_64-macos.tar.gz' },
  'darwin-arm64': { os: 'darwin', cpu: 'arm64', artifact: 'golden-float-aarch64-macos.tar.gz' },
  'win32-x64': { os: 'win32', cpu: 'x64', artifact: 'golden-float-x86_64-win32.zip' },
  'win64-x64': { os: 'win64', cpu: 'x64', artifact: 'golden-float-x86_64-win64.zip' },
};

function download(platformKey) {
  const platform = PLATFORMS[platformKey];
  const tag = process.argv[2] || 'v1.0.0';
  const url = `${REPO}/releases/download/${tag}/${platform.artifact}`;

  console.log(`Downloading ${platform.artifact}...`);

  const outputPath = path.join(__dirname, 'bin', 'golden-float');
  const tarPath = path.join(outputPath, platform.artifact);

  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(tarPath);
    https.get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`Failed to download: ${res.statusCode}`));
        return;
      }

      res.pipe(file)
        .on('finish', () => {
          console.log(`Extracting ${platform.artifact}...`);
          const cmd = platform.artifact.endsWith('.zip') ? 'unzip' : 'tar';
          const args = cmd === 'unzip'
            ? ['-o', path.join(outputPath, 'bin'), tarPath]
            : ['-xzf', tarPath, '-C', outputPath];

          const child = child_process.spawn(cmd, args, { stdio: 'inherit' });

          child.on('close', () => {
            console.log(`✅ ${platform.artifact} installed to ${outputPath}`);
            resolve();
          });

          child.on('error', (err) => {
            console.error(`❌ Error extracting ${platform.artifact}:`, err.message);
            reject(err);
          });
        });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

function installAll() {
  console.log('🚀 Installing GoldenFloat binaries...\n');

  const platformKey = process.argv[3] || getPlatformKey();

  if (!PLATFORMS[platformKey]) {
    console.error(`❌ Unknown platform: ${platformKey}`);
    console.log('Available platforms:', Object.keys(PLATFORMS).join(', '));
    process.exit(1);
  }

  const binaryPath = path.join(__dirname, 'bin', 'golden-float');
  fs.mkdirSync(binaryPath, { recursive: true });

  download(platformKey)
    .then(() => {
      const executable = binaryPath + (platformKey.includes('win') ? '.exe' : '');
      console.log(`\n✅ GoldenFloat v${process.argv[2] || '1.0.0'} installed!`);
      console.log(`\n📍 Binary location: ${executable}`);
      console.log(`\n💡 Usage: const golden = @import("golden_float");`);
    })
    .catch((err) => {
      console.error('❌ Installation failed:', err.message);
      process.exit(1);
    });
}

function getPlatformKey() {
  const platform = process.platform;
  const arch = process.arch;

  if (platform === 'darwin') {
    return arch === 'arm64' ? 'darwin-arm64' : 'darwin-x64';
  }

  if (platform === 'linux') {
    return arch === 'arm64' ? 'linux-arm64' : 'linux-x64';
  }

  if (platform === 'win32') {
    return 'win32-x64';
  }

  return 'win64-x64';
}

// Detect platform if not specified
if (!process.argv[3]) {
  const key = getPlatformKey();
  console.log(`🔍 Auto-detected platform: ${key}`);
  console.log(`\nTo override: npm install -g @golden-float/cli@v1.0.0 [platform]\n`);
}

// Install
installAll();
