# 北科大程式設計考試環境 (NTUT Exam Environment Setup)

本專案為北科大程式設計考試系統的整合部署與環境配置工具。提供自動化腳本，能協助您快速完成主機系統 (`host`)、評測機 (`Piston`) 與學生端 (`desktop`) 的環境建置與組態同步。

---

## 系統需求 (Prerequisites)

- **Node.js**：**Node.js >= 20.19.0**（若主系統選擇非 Docker 部署為必備；因後端 CommonJS 載入 ESM 套件需支援）。
- **Docker Desktop**：必備（無論主系統是否使用 Docker，Piston 程式碼沙盒評測機均依賴 Linux 隔離容器運行）。
- **Git Bash**：Windows 使用者強烈建議，且建議以**系統管理員身分**執行（以利只開放學生 API 的 Windows 防火牆規則）。
- **pnpm**：`pnpm >= 9`（主系統專案採用 pnpm workspace 管理）。

---

## 專案結構說明

本環境部署工具設計可相容以下目錄佈局：
```text
ntut-exam-v2/
├── host/                     # 考試主系統 (後端 Express + 前端 Vue)
├── desktop/                  # 學生端桌面應用程式 (Electron + Vue)
└── ntut-exam-env-setup/       # 本部署專案
    ├── setup.sh              # 核心互動式自動部署與環境設定腳本
    ├── start-host.sh         # 主機系統啟動腳本 (檢查 Piston 並啟動 host)
    ├── piston.sh             # Piston 容器啟動與語言套件安裝工具
    ├── build-desktop.sh      # 學生端程式打包與同步工具
    ├── docker-compose.yaml   # Piston 評測機獨立 Docker 設定
    └── client-setting/       # 學生端派送包 (含腳本、檢測工具與 pre_settings.json)
```

---

## 快速自動化部署 (Quick Setup)

在終端機（Windows 請開啟 Git Bash，建議以管理員身分執行）執行：

```bash
bash setup.sh
```

### 互動式設定流程：

1. **專案定位**：自動偵測同層或子目錄下的 `host` 與 `desktop` 專案；若未下載 `host`，會自動 clone 相容的 `ntut-exam-v2/develop` 分支。若已有舊版 `host`，腳本會在修改設定前停止並說明版本不相容。
2. **通訊埠與伺服器 IP 設定**：
   - 管理 API Port（預設 `3000`，只供本機管理）
   - 學生 API Port（預設 `3001`，供學生端連線）
   - 前端網站 Port（預設 `5173`）
   - Piston 評測服務 Port（預設 `2000`）
   - 伺服器對外 / 區網 IP：腳本會自動偵測本機真實 IP，並將此 IP 與學生 API Port 寫入學生端 `pre_settings.json`。
3. **安全金鑰 (Admin Token)**：
   - 系統採用 `ADMIN_TOKEN` 驗證。可手動輸入至少 16 字元的安全金鑰，或由腳本自動產生。前端建置會包含此值，因此管理前端與管理 API 預設都只綁定本機。
4. **選擇部署模式**：
   - **[1] Docker 完整部署 (推薦)**：
     - 前端、後端與 Piston 均封裝於容器中運行；Piston 由本部署工具的 Compose 管理，host Compose 只啟動前後端，避免同名容器衝突。
     - 寫入 `host/.env`：`ADMIN_PORT`、`USER_PORT`、`ADMIN_TOKEN` 與管理端本機綁定設定。
     - 完整保留 `host/docker-compose.yml` 之生產環境調校（含 tmpfs 任務目錄、沙盒限制與持久化儲存）。
     - `setup.sh` 先啟動本專案的 Piston，再使用 host Compose 建置與啟動前後端。
     - 部署完成前會檢查 Piston、管理 API、學生 API 與管理前端均可連線；管理頁面請在部署主機開啟 `http://127.0.0.1:5173`（若自訂 Port，使用自訂值）。
   - **[2] 本機 Node.js 部署**：
     - 自動檢查本機 Node.js 版本（確保 `>= 20.19.0`）。
     - 自動產生 `host/backend/.env`（雙埠、token）與 `host/frontend/.env`（管理 API URL、同一 token）。
     - 自動啟動 Piston 容器，並透過 `pnpm install` 與 `pnpm build` 建置系統。
     - 支援以 **PM2** 常駐於背景運行，或以手動指令前台執行。
5. **Windows 防火牆設定**：以管理員身分執行時，只會開放學生 API Port；不會自動開放管理 API 或前端。
6. **Piston 評測機語言套件安裝**：
   - 提供互動選單快速安裝：`Python (3.12.0)` 與 `GCC (C/C++ 10.2.0)`。
7. **學生端設定自動同步**：
   - 自動更新 `client-setting/pre_settings.json` 的 `remoteHost` 為伺服器真實 IP 與學生 API Port。
   - 若 `desktop` 已編譯 Windows 安裝檔，自動複製至 `client-setting/ntut-code-tester.exe`。

---

## Piston 評測機維護 (`piston.sh`)

Piston 是執行學生提交程式碼的沙盒引擎。本專案已套用官方優化參數：
- **編譯逾時上限**：`PISTON_COMPILE_TIMEOUT=30000`（30 秒，避免被主系統逾時拒絕）。
- **最大輸出大小**：`PISTON_OUTPUT_MAX_SIZE=65536`（64 KB，保留完整編譯診斷）。
- **沙盒隔離**：`privileged: true` 與 tmpfs 掛載 `/piston/jobs`。
- **持久化保存**：語言包保存於 Docker volume，重啟不需重新下載。

### 常用指令：

```bash
# 啟動 Piston 並自動安裝 Python 與 GCC
bash piston.sh

# 自訂安裝指定語言 (例如加入 Java)
bash piston.sh python gcc java
```

### 使用 USB 搬移語言套件

先在來源機器安裝並確認語言可用，再執行 `bash pack-piston/export.sh`。腳本會產生 `pack-piston/piston-packages.tar.gz`，可將此檔案複製到 USB。

在新機器先啟動 Piston 容器，將 USB 中的壓縮檔複製到新機的 `pack-piston/` 目錄，執行 `bash pack-piston/import.sh`。腳本會把套件放進容器、重啟 Piston，並列出可用語言。若 Piston 對外連接埠不是 2000，執行時指定 `PISTON_PORT`。來源與目標機器須使用相容的 Docker 平台架構。

匯入後無需再執行 `piston.sh` 的語言安裝步驟。若使用完整 Docker 部署，`host/docker-compose.yml` 目前沒有掛載 `/piston/packages`；重建該容器會失去匯入的套件，需再次匯入。

---

## 主系統服務管理 (若選擇本機 Node.js 部署)

### 方式 A：透過 PM2 管理 (背景常駐)

- **查看運行中服務**：`pm2 list`
- **查看即時日誌**：`pm2 logs` (或 `pm2 logs ntut-backend`)
- **重啟服務**：`pm2 restart ntut-backend` 或 `pm2 restart ntut-frontend`
- **停止服務**：`pm2 stop all`
- **刪除服務**：`pm2 delete all`

### 方式 B：手動指令啟動

```bash
# 透過整合腳本 (會先確認 Piston 運行後啟動 host)
bash start-host.sh

# 或直接在 host 目錄下
cd host
pnpm start
```

---

## 學生端應用程式 (`desktop`) 打包與派送

學生端應用程式為基於 Electron 開發之客戶端。

### 1. 打包學生端安裝檔 (`build-desktop.sh`)

在 Windows 環境或具備 Wine 的環境下：

```bash
bash build-desktop.sh
```

- 選項 `1`：進入 `desktop` 執行 `npm run build:win`，產出安裝檔並自動同步至 `client-setting/ntut-code-tester.exe`。
- 選項 `2`：僅將 `desktop/dist` 現有安裝檔同步至 `client-setting/`。
- 選項 `3`：將 `client-setting/` 壓縮為 `client-deploy.zip`，方便直接派送至廣播軟體。

---

### 2. 學生電腦遠端控制與派送指南 (使用廣播軟體)

#### 步驟 A：一鍵自動化安裝與環境檢測 (推薦)

將 `client-setting` 資料夾派送到學生電腦（例如桌面），在學生電腦上以管理員身分執行：

```bat
"%USERPROFILE%\Desktop\client-setting\test-deploy-v2.bat"
```

此腳本將自動執行：
1. **執行 `test-v2.ps1` 進行環境測試**：檢測 VS Code、VMware、Code::Blocks、C/C++ 編譯器（gcc/g++/clang 指標與記憶體測試）以及 Python 執行環境。
2. **自動安裝 `ntut-code-tester.exe`**。
3. **部署 `pre_settings.json`** 至應用程式目錄。
4. **背景靜默啟動 `NTUTOnMachineTest.exe`**。

---

#### 步驟 B：手動分步指令

1. **安裝學生端程式**：
   ```bat
   "%USERPROFILE%\Desktop\ntut-code-tester-2.9.0-setup.exe" && exit
   ```

2. **刪除安裝檔**：
   ```bat
   del "%USERPROFILE%\Desktop\ntut-code-tester-2.9.0-setup.exe" && exit
   ```

3. **派送 `pre_settings.json` 設定檔**：
   請確認檔案內容中的 `remoteHost` 已指向伺服器真實 IP：
   ```json
   {
     "testTitle": "北科大計算機程式設計考試",
     "description": "測驗時間請遵從現場監考人員指示",
     "remoteHost": "http://192.168.1.100:3001"
   }
   ```
   將此檔案派送至學生桌面後，執行以下指令移動至程式資源目錄：
   ```bat
   move /Y "%USERPROFILE%\Desktop\pre_settings.json" "%LOCALAPPDATA%\Programs\ntut-code-tester\resources\pre_settings.json" && exit
   ```

4. **啟動學生端應用程式**：
   ```bat
   start "" "%LOCALAPPDATA%\Programs\ntut-code-tester\NTUTOnMachineTest.exe" && exit
   ```

5. **強制關閉學生端應用程式 (若有需要)**：
   ```bat
   taskkill /IM NTUTOnMachineTest.exe /F && exit
   ```

---

## 考試前自我測試

主系統部署完成後，請於瀏覽器進入管理後台：
- **網址**：`http://127.0.0.1:5173/judge`（在主機本機開啟；自訂前端 Port 時請替換）
- 切換至 **Deploy Test** 分頁：
  - 系統將會發送 probe 測試 Piston 的 C、C++、Python 實際編譯與運行狀態。
  - 驗證 CE、RE、TLE、MLE 等判定行為。
  - 檢視系統負載與並發佇列處理狀況。
