import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('../setup-server-ip.sh', import.meta.url));

// 模擬 Windows 程式輸出，讓非 Windows 開發機也能驗證 Bash 端行為。
function run(body, { addresses = '', input = '', failure = false } = {}) {
    return spawnSync('bash', ['-c', `
        set -eo pipefail
        source "$1"
        powershell.exe() {
            if [ "$MOCK_FAILURE" = true ]; then
                echo 'Windows IPv4 detection failed: access denied' >&2
                return 1
            fi
            printf '%s' "$MOCK_ADDRESSES"
        }
        ${body}
    `, 'test', script], {
        encoding: 'utf8', input,
        env: { ...process.env, MOCK_ADDRESSES: addresses, MOCK_FAILURE: String(failure) },
    });
}

test('Windows CRLF 輸出保留校園公有 IP、私有 IP 與原始優先順序，並去除重複', () => {
    const result = run('detect_server_ipv4', {
        addresses: '140.124.20.30\r\n192.168.1.20\r\n10.0.0.20\r\n172.20.0.2\r\n140.124.20.30\r\n',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, '140.124.20.30\n192.168.1.20\n10.0.0.20\n172.20.0.2\n');
});

test('排除回送、自動配置、非標準及無效位址', () => {
    const result = run('detect_server_ipv4', {
        addresses: '0.0.0.0\n127.0.0.1\n169.254.1.2\n224.0.0.1\n255.255.255.255\n192.168.1.256\n010.0.0.1\n::1\nerror message\n140.124.20.30\n',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, '140.124.20.30\n');
});

test('確認預設校園公有 IP 後才設定 SERVER_IP', () => {
    const result = run('USER_PORT=3000; confirm_server_ip; printf "RESULT=%s/%s\\n" "$SERVER_IP" "$SERVER_IP_CONFIRMED"', {
        addresses: '140.124.20.30\r\n192.168.1.20\r\n', input: '\ny\n',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /RESULT=140\.124\.20\.30\/140\.124\.20\.30/);
});

test('Windows 查詢失敗時保留診斷並允許手動輸入', () => {
    const result = run('USER_PORT=3000; confirm_server_ip; printf "RESULT=%s\\n" "$SERVER_IP"', {
        failure: true, input: '140.124.20.30\ny\n',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stderr, /access denied/);
    assert.match(result.stdout, /ipconfig/);
    assert.match(result.stdout, /RESULT=140\.124\.20\.30/);
});

test('無候選時可手動輸入，拒絕回送位址', () => {
    const result = run('USER_PORT=3000; confirm_server_ip; printf "RESULT=%s\\n" "$SERVER_IP"', {
        input: '127.0.0.1\n192.168.1.50\ny\n',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /請輸入有效 IPv4/);
    assert.match(result.stdout, /RESULT=192\.168\.1\.50/);
});

test('輸入結束時停止，不自動確認 IP', () => {
    const result = run('USER_PORT=3000; confirm_server_ip', { addresses: '140.124.20.30\n' });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /未確認 IP/);
});
