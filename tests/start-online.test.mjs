import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { configureStudentFirewall } from '../start-online.mjs';

const source = new URL('../start-online.mjs', import.meta.url);
const token = 'test-token-1234567890';

test('Windows 防火牆只開放指定學生 TCP Port，重啟前先清除同名規則', () => {
    const calls = [];
    const execute = (...args) => { calls.push(args); return { status: 0 }; };
    assert.equal(configureStudentFirewall(4321, { platform: 'win32', execute }), true);
    assert.deepEqual(calls.map(([command, args]) => [command, args]), [
        ['netsh.exe', ['advfirewall', 'firewall', 'delete', 'rule', 'name=NTUT Online Student (4321)']],
        ['netsh.exe', ['advfirewall', 'firewall', 'add', 'rule', 'name=NTUT Online Student (4321)',
            'dir=in', 'action=allow', 'protocol=TCP', 'localport=4321', 'profile=any']],
    ]);
    assert.equal(calls[1][2].shell, undefined);
});

test('非 Windows 不執行防火牆指令', () => {
    assert.equal(configureStudentFirewall(3003, {
        platform: 'linux', execute: () => assert.fail('不應呼叫 netsh'),
    }), false);
});

test('防火牆新增失敗或無法執行時，不回報成功且不中止網站啟動', () => {
    for (const result of [{ status: 1 }, { status: null, error: new Error('ENOENT') }]) {
        assert.equal(configureStudentFirewall(3003, { platform: 'win32', execute: () => result }), false);
    }
});

async function fixture(t) {
    const root = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'online-launcher-')));
    const online = path.join(root, 'ntut-exam-online');
    await fs.copyFile(source, path.join(root, 'start-online.mjs'));
    for (const entry of ['host/backend', 'apps/backend/src', 'apps/backend/dist', 'apps/frontend/dist', 'apps/ta/dist']) {
        await fs.mkdir(entry.startsWith('host') ? path.join(root, entry) : path.join(online, entry), { recursive: true });
    }
    for (const entry of ['package.json', 'apps/frontend/package.json', 'apps/ta/package.json']) {
        await fs.writeFile(path.join(online, entry), '{"type":"module"}');
    }
    for (const entry of ['apps/backend/src/app.ts', 'apps/frontend/dist/index.html', 'apps/ta/dist/index.html']) {
        await fs.writeFile(path.join(online, entry), 'fixture');
    }
    await fs.writeFile(path.join(online, 'apps/backend/dist/app.js'), `
        export const userApp = (req, res) => res.end(JSON.stringify({
            role: 'user', host: process.env.V2_API_URL,
            tokenMatches: process.env.ADMIN_TOKEN === '${token}',
            cwd: process.cwd(), target: process.env.TARGET_FOLDER
        }));
        export const adminApp = (req, res) => res.end(JSON.stringify({ role: 'admin', address: req.socket.localAddress }));
    `);
    const host = createServer((req, res) => {
        res.writeHead(req.url === '/admin/config' && req.headers['x-admin-token'] === token ? 200 : 401, { 'content-type': 'application/json' });
        res.end('{}');
    });
    host.listen(0, '127.0.0.1');
    await once(host, 'listening');
    const hostPort = host.address().port;
    const hostEnv = `ADMIN_PORT=${hostPort}\nUSER_PORT=3000\nADMIN_TOKEN="${token}"\n`;
    await fs.writeFile(path.join(root, 'host/backend/.env'), hostEnv);
    t.after(async () => { host.closeAllConnections(); await new Promise((resolve) => host.close(resolve)); await fs.rm(root, { recursive: true, force: true }); });
    return { root, hostPort, hostEnv };
}

async function freePort() {
    const server = createServer();
    server.listen(0, '0.0.0.0');
    await once(server, 'listening');
    const port = server.address().port;
    await new Promise((resolve) => server.close(resolve));
    return port;
}

function launch(t, root, args, input = '') {
    const child = spawn(process.execPath, [path.join(root, 'start-online.mjs'), ...args], {
        cwd: os.tmpdir(), env: { ...process.env, HOST_DIR: path.join(root, 'host'), ONLINE_DIR: path.join(root, 'ntut-exam-online') },
        stdio: ['pipe', 'pipe', 'pipe'],
    });
    let output = '';
    child.stdout.on('data', (data) => { output += data; });
    child.stderr.on('data', (data) => { output += data; });
    child.stdin.end(input);
    const done = once(child, 'exit');
    t.after(() => { if (child.exitCode === null) child.kill('SIGKILL'); });
    return { child, done, output: () => output };
}

test('首次設定、讀取 host 認證、啟動兩個網站、停止並沿用設定重啟', { timeout: 15000 }, async (t) => {
    const { root, hostPort, hostEnv } = await fixture(t);
    const userPort = await freePort();
    let adminPort = await freePort();
    while (adminPort === userPort) adminPort = await freePort();
    const input = `${userPort}\n${adminPort}\n192.168.1.20\n\n`;
    for (let attempt = 0; attempt < 2; attempt++) {
        const process = launch(t, root, ['--skip-build'], attempt ? '' : input);
        const deadline = Date.now() + 5000;
        while (!process.output().includes('✅ TA')) {
            if (process.child.exitCode !== null || process.child.signalCode || Date.now() > deadline) assert.fail(process.output());
            await new Promise((resolve) => setTimeout(resolve, 25));
        }
        const user = await (await fetch(`http://127.0.0.1:${userPort}/api/health`)).json();
        assert.equal(user.host, `http://127.0.0.1:${hostPort}`);
        assert.equal(user.tokenMatches, true);
        assert.equal(user.cwd, path.join(root, 'online-data'));
        assert.equal(user.target, path.join(root, 'online-data/target'));
        const admin = await (await fetch(`http://127.0.0.1:${adminPort}/api/health`)).json();
        assert.equal(admin.role, 'admin');
        assert.equal(admin.address, '127.0.0.1');
        process.child.kill('SIGINT');
        assert.equal((await process.done)[0], 130);
    }
    const settings = await fs.readFile(path.join(root, 'online-settings.json'), 'utf8');
    assert.equal(settings.includes(token), false);
    assert.equal(await fs.readFile(path.join(root, 'host/backend/.env'), 'utf8'), hostEnv);
});

test('未安裝 host 時停止', async (t) => {
    const { root } = await fixture(t);
    await fs.unlink(path.join(root, 'host/backend/.env'));
    const process = launch(t, root, ['--skip-build']);
    assert.equal((await process.done)[0], 1);
    assert.match(process.output(), /請先使用 setup.sh/);
});

test('online Port 與 host 重複時不保存設定', async (t) => {
    const { root, hostPort } = await fixture(t);
    const process = launch(t, root, ['--skip-build'], `${hostPort}\n3004\n192.168.1.20\n\n`);
    assert.equal((await process.done)[0], 1);
    assert.match(process.output(), /與 host Port 衝突/);
    await assert.rejects(fs.access(path.join(root, 'online-settings.json')));
});

test('host 認證失敗時在建置前停止', async (t) => {
    const { root, hostPort } = await fixture(t);
    await fs.writeFile(path.join(root, 'host/backend/.env'), `ADMIN_PORT=${hostPort}\nADMIN_TOKEN=wrong-token-1234567890\n`);
    const process = launch(t, root, []);
    assert.equal((await process.done)[0], 1);
    assert.match(process.output(), /確認 host 已載入最新設定/);
});
