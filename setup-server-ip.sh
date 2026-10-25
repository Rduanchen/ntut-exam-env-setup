#!/usr/bin/env bash
# 共用的學生連線位址選擇；只讀取本機網卡，不掃描其他電腦。

is_usable_server_ipv4() {
    local address="$1" octet
    local -a octets
    [[ "$address" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
    IFS=. read -r -a octets <<< "$address"
    for octet in "${octets[@]}"; do
        # 避免八進位與非標準 IPv4 表示法。
        [[ "$octet" = 0 || "$octet" != 0* ]] || return 1
        (( 10#$octet <= 255 )) || return 1
    done
    (( octets[0] > 0 && octets[0] < 224 && octets[0] != 127 )) || return 1
    [[ "$address" != 169.254.* ]]
}

detect_server_ipv4() {
    local raw="" address seen=""
    if command -v powershell.exe >/dev/null 2>&1; then
        raw=$(powershell.exe -NoProfile -NonInteractive -Command \
            'Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|Docker|WSL" } | Sort-Object InterfaceIndex | Select-Object -ExpandProperty IPAddress' 2>/dev/null | tr -d '\r') || raw=""
    elif command -v ip >/dev/null 2>&1; then
        raw=$(ip -o -4 addr show up scope global 2>/dev/null | awk '$2 !~ /^(docker|br-|veth|virbr)/ {split($4, a, "/"); print a[1]}') || raw=""
    elif command -v ifconfig >/dev/null 2>&1; then
        raw=$(ifconfig 2>/dev/null | awk '/^[^ \t]/ {iface=$1} $1 == "inet" && iface !~ /^(lo|docker|bridge|veth|utun)/ {print $2}') || raw=""
    fi
    while IFS= read -r address; do
        is_usable_server_ipv4 "$address" || continue
        # 自動建議只列出區網私有位址；手動輸入仍可使用有效的對外位址。
        case "$address" in
            10.*|192.168.*) ;;
            172.*) local second=${address#172.}; second=${second%%.*}; (( second >= 16 && second <= 31 )) || continue ;;
            *) continue ;;
        esac
        [[ " $seen " != *" $address "* ]] || continue
        printf '%s\n' "$address"
        seen="$seen $address"
    done <<< "$raw"
}

confirm_server_ip() {
    local candidates address default_ip="" input answer
    if [ -n "${SERVER_IP_CONFIRMED:-}" ] && [ "$SERVER_IP_CONFIRMED" = "${SERVER_IP:-}" ]; then
        return 0
    fi
    candidates=$(detect_server_ipv4)
    echo "=> 偵測本機區域網 IPv4 位址："
    while IFS= read -r address; do
        [ -n "$address" ] || continue
        echo "   $address"
        [ -n "$default_ip" ] || default_ip=$address
    done <<< "$candidates"
    if is_usable_server_ipv4 "${SERVER_IP:-}"; then
        default_ip=$SERVER_IP
    fi
    if [ -z "$candidates" ]; then
        echo "   未偵測到區網 IP，請手動輸入學生電腦可連線的本機 IPv4。"
    fi
    while true; do
        if ! read -r -p "請選擇或輸入伺服器 IPv4${default_ip:+ (預設: $default_ip)}: " input; then
            echo "❌ 輸入已結束，未確認 IP，不寫入設定檔。" >&2
            return 1
        fi
        address=${input:-$default_ip}
        if ! is_usable_server_ipv4 "$address"; then
            echo "請輸入有效 IPv4；不可使用 0.0.0.0、回送或自動配置位址。"
            continue
        fi
        echo "學生連線網址：http://${address}:${USER_PORT}"
        if ! read -r -p "確認使用此位址並繼續寫入設定？(y/n) [預設: y]: " answer; then
            echo "❌ 輸入已結束，未確認 IP，不寫入設定檔。" >&2
            return 1
        fi
        case "$answer" in
            ""|y|Y)
                SERVER_IP=$address
                SERVER_IP_CONFIRMED=$address
                return 0
                ;;
            n|N) default_ip=$address ;;
            *) echo "請輸入 y 或 n；尚未寫入設定檔。"; default_ip=$address ;;
        esac
    done
}
