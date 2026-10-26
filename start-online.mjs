import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import { createServer } from 'node:http';
import { spawnSync } from 'node:child_process';
import { createInterface } from 'node:readline';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseEnv } from 'node:util';

const root = path.dirname(fileURLToPath(import.meta.url));
const configFile = path.join(root, 'online-settings.json');
const args = process.argv.slice(2);
const exists = (name) => fs.existsSync(name);
const fail = (message) => { throw new Error(message); };
const env = process.env;

function run(command, args, cwd) {
    // Windows 的 pnpm 為 .cmd；git 直接執行，保留含空白路徑的參數邊界。
    const result = spawnSync(command, args, { cwd, stdio: 'inherit', shell: process.platform === 'win32' && command === 'pnpm' });
    if (result.error || result.status !== 0) fail(`${command} 執行失敗，流程停止。`);
}

function findProject(override, candidates) {
    if (override) return path.resolve(override);
    return candidates.find(exists);
}

function port(value, label) {
    if (!/^\d{1,5}$/.test(String(value)) || Number(value) < 1 || Number(value) > 65535) {
        fail(`${label} 必須是 1–65535 的整數。`);
    }
    return Number(value);
}

export function configureStudentFirewall(userPort, { platform = process.platform, execute = spawnSync } = {}) {
    if (platform !== 'win32') return false;
    const value = port(userPort, '學生 Port');
    const name = `name=NTUT Online Student (${value})`;
    // 以獨立名稱更新此 Port 的規則，重新啟動時不累積重複規則。
    execute('netsh.exe', ['advfirewall', 'firewall', 'delete', 'rule', name], { stdio: 'ignore', timeout: 15000 });
    const result = execute('netsh.exe', [
        'advfirewall', 'firewall', 'add', 'rule', name,
        'dir=in', 'action=allow', 'protocol=TCP', `localport=${value}`, 'profile=any',
    ], { stdio: 'inherit', timeout: 15000 });
    if (result.error || result.status !== 0) {
        console.warn(`⚠️ 無法自動開放學生網站 TCP ${value}。請以「系統管理員身分」開啟 Git Bash 後重新執行，或手動設定防火牆；Online 將繼續啟動。`);
        return false;
    }
    console.log(`✅ Windows 防火牆已允許學生網站 TCP ${value}。`);
    return true;
}

async function listen(server, port, host) {
    await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(port, host, resolve);
    });
}

async function checkPort(value, host) {
    const server = net.createServer();
    try {
        await listen(server, value, host);
    } catch {
        fail(`Port ${value} 無法使用（已占用或權限不足），請以 --configure 重新設定。`);
    } finally {
        if (server.listening) await new Promise((resolve) => server.close(resolve));
    }
}

async function main() {
    if (args.includes('--help')) {
        console.log('用法：bash start-online.sh [--configure] [--skip-build]\n首次下載、設定、建置並啟動 online；--configure 重設 online 設定；--skip-build 使用既有建置。');
        return;
    }
    if (args.some((arg) => !['--configure', '--skip-build'].includes(arg))) fail('未知參數，請使用 --help。');
    const [major, minor] = process.versions.node.split('.').map(Number);
    if (major < 20 || (major === 20 && minor < 19) || major === 21 || (major === 22 && minor < 12)) {
        fail('online 建置需要 Node.js 20.19+ 或 22.12+（建議使用 LTS）。');
    }
    console.log('=== NTUT Exam Online：獨立安裝與啟動 ===');
    const hostDir = findProject(env.HOST_DIR, [path.join(root, 'host'), path.resolve(root, '../host')]);
    if (!hostDir || !exists(path.join(hostDir, 'backend/.env'))) fail('找不到 host/backend/.env，請先使用 setup.sh 完成 host 安裝。');
    // 只解析資料，不以 shell source 執行 .env；每次啟動都讀取最新 Token。
    const hostEnv = parseEnv(fs.readFileSync(path.join(hostDir, 'backend/.env'), 'utf8'));
    const hostPort = port(hostEnv.ADMIN_PORT || 3001, 'host ADMIN_PORT');
    if (!/^[A-Za-z0-9_-]{16,}$/.test(hostEnv.ADMIN_TOKEN || '') || hostEnv.ADMIN_TOKEN === 'admin-secret') {
        fail('host ADMIN_TOKEN 無效，請先完成 host 環境設定。');
    }
    const hostUrl = `http://127.0.0.1:${hostPort}`;
    try {
        const response = await fetch(`${hostUrl}/admin/config`, {
            headers: { 'x-admin-token': hostEnv.ADMIN_TOKEN }, signal: AbortSignal.timeout(10000),
        });
        if (!response.ok) fail(`HTTP ${response.status}`);
        await response.json();
    } catch {
        fail(`無法使用現有 Token 連線至 host 管理 API (${hostUrl})，請在另一個終端機執行 bash start-host.sh，並確認 host 已載入最新設定。`);
    }

    let onlineDir = findProject(env.ONLINE_DIR, [path.join(root, 'ntut-exam-online'), path.resolve(root, '../ntut-exam-online')]);
    if (!onlineDir) {
        onlineDir = path.join(root, 'ntut-exam-online');
        console.log('=> 下載 ntut-exam-online/main...');
        run('git', ['clone', '--branch', 'main', '--single-branch', 'https://github.com/Rduanchen/ntut-exam-online.git', onlineDir], root);
    }
    for (const entry of ['package.json', 'apps/backend/src/app.ts', 'apps/frontend/package.json', 'apps/ta/package.json']) {
        if (!exists(path.join(onlineDir, entry))) fail(`online 專案不完整：缺少 ${entry}`);
    }
    console.log(`=> 使用 online：${onlineDir}`);
    let settings = exists(configFile) ? JSON.parse(fs.readFileSync(configFile, 'utf8')) : null;
    if (!settings || args.includes('--configure')) {
        // async iterator 支援終端機及重導輸入，避免一次讀入多行時遺失回答。
        const rl = createInterface({ input: process.stdin, terminal: false });
        const lines = rl[Symbol.asyncIterator]();
        const ask = async (label, defaultValue) => {
            process.stdout.write(`${label} [${defaultValue}]: `);
            const line = await lines.next();
            if (line.done) fail('輸入已結束，尚未儲存 online 設定。');
            return line.value.trim() || defaultValue;
        };
        try {
            let defaultIp = env.SERVER_IP || settings?.serverIp;
            const clientFile = path.join(root, 'client-setting/pre_settings.json');
            if (!defaultIp && exists(clientFile)) {
                try { defaultIp = new URL(JSON.parse(fs.readFileSync(clientFile, 'utf8')).remoteHost).hostname; } catch { /* 手動輸入 */ }
            }
            settings = {
                userPort: port(await ask('online 學生網站 Port', settings?.userPort || 3003), '學生 Port'),
                adminPort: port(await ask('online TA 後台 Port（僅本機）', settings?.adminPort || 3004), 'TA Port'),
                serverIp: await ask('學生可連線的伺服器 IPv4', defaultIp || ''),
                targetFolder: path.resolve(root, await ask('作答檔案保存目錄', settings?.targetFolder || path.join(root, 'online-data/target'))),
            };
        } finally {
            rl.close();
        }
    }
    settings.userPort = port(settings.userPort, '學生 Port');
    settings.adminPort = port(settings.adminPort, 'TA Port');
    if (!net.isIPv4(settings.serverIp) || /^(0\.|127\.|169\.254\.)/.test(settings.serverIp) || Number(settings.serverIp.split('.')[0]) >= 224) {
        fail('請以 --configure 設定學生可連線的有效 IPv4（不可使用回送位址或 0.0.0.0）。');
    }
    if (typeof settings.targetFolder !== 'string' || !path.isAbsolute(settings.targetFolder)) fail('作答保存目錄必須是絕對路徑，請以 --configure 重設。');
    const hostPorts = ['ADMIN_PORT', 'USER_PORT', 'FRONTEND_PORT', 'PISTON_PORT'].map((key, i) => port(hostEnv[key] || [3001, 3000, 5173, 2000][i], `host ${key}`));
    if (settings.userPort === settings.adminPort || [settings.userPort, settings.adminPort].some((value) => hostPorts.includes(value))) {
        fail('online 學生／TA Port 不可重複或與 host Port 衝突，請以 --configure 重設。');
    }
    await checkPort(settings.userPort, '0.0.0.0');
    await checkPort(settings.adminPort, '127.0.0.1');
    fs.writeFileSync(configFile, `${JSON.stringify(settings, null, 2)}\n`, { mode: 0o600 });

    if (!args.includes('--skip-build')) {
        const version = spawnSync('pnpm', ['--version'], { encoding: 'utf8', shell: process.platform === 'win32' });
        if (version.status !== 0 || Number(version.stdout.trim().split('.')[0]) < 10) fail('需要 pnpm >= 10，請先執行 npm install -g pnpm@10。');
        run('pnpm', ['install', '--frozen-lockfile'], onlineDir);
        // 固定為同源 /api，避免環境變數或 Turbo 舊快取帶入管理端位址。
        env.VITE_API_BASE_URL = '/api';
        run('pnpm', ['exec', 'turbo', 'build', '--force', '--env-mode=loose'], onlineDir);
    }
    for (const entry of ['apps/backend/dist/app.js', 'apps/frontend/dist/index.html', 'apps/ta/dist/index.html']) {
        if (!exists(path.join(onlineDir, entry))) fail(`缺少建置產物 ${entry}，請移除 --skip-build 重新執行。`);
    }
    const dataDir = path.join(root, 'online-data');
    for (const dir of [dataDir, settings.targetFolder, path.join(dataDir, 'upload'), path.join(dataDir, 'to-judge')]) fs.mkdirSync(dir, { recursive: true });
    const onlineEnv = {
        V2_API_URL: hostUrl, ADMIN_TOKEN: hostEnv.ADMIN_TOKEN,
        USER_PORT: String(settings.userPort), ADMIN_PORT: String(settings.adminPort),
        TARGET_FOLDER: settings.targetFolder,
        FRONTEND_DIST_DIR: path.join(onlineDir, 'apps/frontend/dist'),
        TA_DIST_DIR: path.join(onlineDir, 'apps/ta/dist'),
    };
    fs.writeFileSync(path.join(onlineDir, 'apps/backend/.env'),
        Object.entries(onlineEnv).map(([key, value]) => `${key}=${JSON.stringify(value.replaceAll('\\', '/'))}`).join('\n') + '\n',
        { mode: 0o600 });
    Object.assign(env, onlineEnv);
    process.chdir(dataDir);
    // 使用原專案的 Express apps，明確限制 TA 僅綁定本機；不修改 online 原始碼。
    const { userApp, adminApp } = await import(pathToFileURL(path.join(onlineDir, 'apps/backend/dist/app.js')).href);
    const servers = [];
    let stopping = false;
    const stop = (code) => {
        if (stopping) return;
        stopping = true;
        const timer = setTimeout(() => process.exit(code), 5000);
        Promise.all(servers.map((server) => new Promise((resolve) => {
            server.close(resolve);
            server.closeIdleConnections();
        }))).then(() => { clearTimeout(timer); process.exit(code); });
    };
    process.on('SIGINT', () => stop(130));
    process.on('SIGTERM', () => stop(143));
    try {
        for (const [app, value, address] of [[userApp, settings.userPort, '0.0.0.0'], [adminApp, settings.adminPort, '127.0.0.1']]) {
            const httpServer = createServer(app);
            servers.push(httpServer);
            await listen(httpServer, value, address);
            httpServer.on('error', (error) => { console.error(error.message); stop(1); });
        }
    } catch (error) {
        console.error(`啟動失敗：${error.message}`);
        stop(1);
        return;
    }
    const firewallConfigured = configureStudentFirewall(settings.userPort);
    console.log(`✅ 學生網站：http://${settings.serverIp}:${settings.userPort}`);
    console.log(`✅ TA 後台：http://127.0.0.1:${settings.adminPort}`);
    console.log(`作答目錄：${settings.targetFolder}\n執行資料目錄：${dataDir}\n按 Ctrl+C 停止 online。`);
    if (!exists(path.join(dataDir, 'exam.zip'))) console.log(`提示：題目附件請放在 ${path.join(dataDir, 'exam.zip')}，否則 /api/pdf 回傳 404。`);
    if (!firewallConfigured) console.log(`請確認主機防火牆允許學生連入 TCP ${settings.userPort}。`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    main().catch((error) => { console.error(`❌ ${error.message}`); process.exitCode = 1; });
}
