#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用本次部署設定。

echo "=> 從 pack-piston/piston-packages.tar.gz 匯入 Piston 語言套件..."
# 使用子程序，避免 import.sh 的 SCRIPT_DIR 與 shell 選項覆蓋主腳本。
PISTON_PORT="$PISTON_PORT" bash "$SCRIPT_DIR/pack-piston/import.sh"
echo "✅ Piston 語言套件已匯入，後續可略過 setup-piston-language.sh。"
