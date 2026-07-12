import fs from 'fs';
import { execSync } from 'child_process';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.join(__dirname, '..');
const ROBLOX_DIR = path.join(ROOT_DIR, 'roblox');
const BUILDS_DIR = path.join(ROBLOX_DIR, 'builds');

if (!fs.existsSync(BUILDS_DIR)) {
    fs.mkdirSync(BUILDS_DIR, { recursive: true });
}

// 1. Read version from package.json
const pkgPath = path.join(ROOT_DIR, 'package.json');
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const version = pkg.version || '0.1.0';

// 2. Increment build number
const versionJsonPath = path.join(ROBLOX_DIR, 'build-version.json');
let buildData = { buildNumber: 0 };
if (fs.existsSync(versionJsonPath)) {
    buildData = JSON.parse(fs.readFileSync(versionJsonPath, 'utf8'));
}
buildData.buildNumber += 1;
fs.writeFileSync(versionJsonPath, JSON.stringify(buildData, null, 2));

// 3. Generate name
const bNum = String(buildData.buildNumber).padStart(4, '0');
const now = new Date();
const dateStr = now.toISOString().replace(/[-:]/g, '').replace('T', '-').slice(0, 15);

let gitsha = 'unknown';
try {
    gitsha = execSync('git rev-parse --short HEAD', { cwd: ROOT_DIR }).toString().trim();
} catch (e) {}

const baseName = `Norderstedt_MVP_v${version}-b${bNum}_${dateStr}_${gitsha}.rbxlx`;
const buildPath = path.join(BUILDS_DIR, baseName);

if (fs.existsSync(buildPath)) {
    console.error("Build target already exists!");
    process.exit(1);
}

// 4. Run Rojo
console.log(`Building ${baseName}...`);
try {
    // Falls rokit installiert ist, wird rojo build funktionieren.
    execSync(`.\\rokit.exe run rojo build roblox/default.project.json -o "${buildPath}"`, { cwd: ROOT_DIR, stdio: 'inherit' });
} catch (e) {
    try {
        // Fallback
        execSync(`rojo build roblox/default.project.json -o "${buildPath}"`, { cwd: ROOT_DIR, stdio: 'inherit' });
    } catch(e2) {
        console.error("Failed to build with Rojo.");
        process.exit(1);
    }
}

// 5. Size and Hash
const stats = fs.statSync(buildPath);
const fileBuffer = fs.readFileSync(buildPath);
const hashSum = crypto.createHash('sha256');
hashSum.update(fileBuffer);
const hex = hashSum.digest('hex');

// 6. Write sidecar JSON
const sidecarPath = path.join(BUILDS_DIR, `${baseName}.json`);
const sidecar = {
    version: version,
    buildNumber: buildData.buildNumber,
    timestamp: now.toISOString(),
    gitsha: gitsha,
    sizeBytes: stats.size,
    sha256: hex,
    file: baseName
};
fs.writeFileSync(sidecarPath, JSON.stringify(sidecar, null, 2));

// 7. Update LATEST.txt
const latestPath = path.join(BUILDS_DIR, 'LATEST.txt');
fs.writeFileSync(latestPath, baseName);

console.log(`Successfully built ${baseName}`);
console.log(`Size: ${stats.size} bytes`);
console.log(`SHA-256: ${hex}`);
