# 北科大程式設計考試環境 (NTUT Exam Environment Setup)

本專案提供考試主系統（host）、Piston 評測機及學生端連線設定的部署指令。請先完成 host 安裝，再依教室需求選擇學生端：可安裝程式的電腦使用 desktop 派送包；無法安裝程式的電腦另外執行 `start-online.sh`，讓學生以瀏覽器作答。

## 第一步：準備主機環境

以下指令都在教師端／考試伺服器執行。Windows 請使用 Git Bash，首次設定建議以系統管理員身分開啟，以便設定學生 API 的防火牆規則。

安裝並確認下列工具：

| 工具 | 需求與用途 |
| --- | --- |
| Git | 下載部署工具與 host／online 專案 |
| Node.js 與 npm | host 需要 Node.js >= 20.19.0；online 支援 Node.js 20.19+ 或 22.12+，不支援 21 |
| pnpm | host 需要 >= 9；若要使用 online，請準備 >= 10 |
| Docker Desktop／Docker Engine | 執行 Piston；需先啟動 Docker，並能使用 `docker compose` |
| curl | 安裝流程用來檢查服務與安裝 Piston 語言套件 |

在 Git Bash／終端機檢查：

```bash
node --version
npm --version
pnpm --version
git --version
docker info
docker compose version
curl --version
```

若尚未安裝 pnpm，或要升級至 online 所需版本：

```bash
npm install -g pnpm@10
```

## 第二步：下載並進入部署工具目錄

```bash
git clone https://github.com/Rduanchen/ntut-exam-env-setup.git
cd ntut-exam-env-setup
```

若已下載本專案，直接在既有 `ntut-exam-env-setup` 目錄開啟終端機即可。

host 與 online 可以放在本目錄內，也可以放在同層；腳本會優先使用本目錄內的專案。找不到時，安裝流程會下載至本目錄。

```text
ntut-exam-env-setup/
├── setup.sh                  # host、Piston 與學生端連線設定
├── start-host.sh             # 啟動 host
├── start-online.sh           # 獨立安裝與啟動 online 的指令入口
├── start-online.mjs          # online 設定、建置及服務啟停邏輯
├── piston.sh                 # Piston 啟動與語言套件維護
├── docker-compose.yaml       # Piston 容器設定
├── pack-piston/              # 語言套件匯出／匯入工具
├── client-setting/           # desktop 派送包與 pre_settings.json
├── host/                     # 自動下載的 host（也可位於同層）
├── ntut-exam-online/          # 選用；自動下載的 online（也可位於同層）
├── online-settings.json      # 首次設定 online 後產生
└── online-data/              # online 執行資料與預設作答保存目錄
```

## 第三步：安裝 host 與 Piston

在部署工具目錄執行：

```bash
bash setup.sh
```

每個階段都會詢問是否執行：直接按 Enter 或輸入 `y` 執行，輸入 `n` 略過。第一次部署請依序完成必要階段；`setup-*.sh` 會共用設定，請透過 `setup.sh` 執行。

依畫面順序操作：

1. **定位或下載 host**：沒有 host 時，同意下載 `ntut-exam-v2` 的 `develop` 分支。既有 host 需支援雙 API Port 與管理 Token，版本不符時流程會停止。
2. **設定 Port 與主機 IP**：一般可沿用下表預設值。從偵測結果選擇學生電腦能連線的本機 IPv4（支援私有 IP 與校園公有 IP）；Windows 優先列出有預設閘道的實體網卡，多網卡時仍請確認選對教室網卡。若無法偵測，可在 Windows 執行 `ipconfig`，手動輸入教室乙太網路／Wi-Fi 網卡的 IPv4 位址。不要填閘道位址、`0.0.0.0` 或 `127.0.0.1`。
3. **設定 Admin Token**：直接按 Enter 自動產生；若手動指定，至少 16 字元，僅使用英數字、底線或連字號。腳本會寫入 host 前後端 `.env`，管理前端與管理 API 僅供主機本機使用。
4. **檢查 Node.js 與 pnpm，啟動 Piston**：確認 Docker 已運行。
5. **選擇是否匯入語言套件**：若已有 `pack-piston/piston-packages.tar.gz`，執行匯入；沒有此檔時請輸入 `n`，稍後改用語言安裝階段。
6. **安裝與建置 host**：執行相依套件安裝及前後端建置。
7. **設定 Windows 防火牆**：若以系統管理員執行，可同意開放學生 API Port；管理 API 與管理前端不會自動開放。其他環境或未以管理員執行時，請自行允許學生 API 的 TCP Port。
8. **安裝 Piston 語言套件**：需要 C／C++ 與 Python 時選 `3`。若已成功匯入所需套件，可略過此階段。
9. **產生學生端連線設定**：確認 IP 後更新 `client-setting/pre_settings.json`。此階段只產生設定，不會下載或複製 desktop 安裝檔。
10. **啟動 host**：最後詢問是否執行 `start-host.sh` 時，按 Enter 啟動，並保持此終端機開啟。本次已建置時不會重複建置。

| 服務 | 預設 Port | 使用方式 |
| --- | --- | --- |
| host 管理 API | 3001 | 僅本機，供管理前端及 online backend 使用 |
| host 學生 API | 3000 | 供 desktop 學生端連線 |
| host 管理前端 | 5173 | 僅本機瀏覽器使用 |
| Piston | 2000 | 供 host 評測使用 |
| online 學生網站（選用） | 3003 | 供學生瀏覽器連線 |
| online TA 後台（選用） | 3004 | 僅本機瀏覽器使用 |

如果略過 host 環境設定階段，既有 `.env` 不會被重寫，但其他 setup 階段仍使用本次預設值或環境變數。既有環境使用自訂 Port 時，請在執行前指定一致的值，例如：

```bash
ADMIN_PORT=3101 USER_PORT=3100 FRONTEND_PORT=5174 PISTON_PORT=2100 bash setup.sh
```

## 第四步：確認 host 可使用

等待終端機顯示服務就緒，再在主機瀏覽器開啟：

```text
http://127.0.0.1:5173/judge
```

若使用自訂管理前端 Port，請替換 `5173`。在管理後台確認考卷與評測設定，並執行文末「考試前自我測試」。

若 setup 最後沒有啟動 host，或之後需要重啟，在部署工具目錄執行：

```bash
bash start-host.sh
```

此指令會檢查 Piston、安裝依賴、建置並啟動 host。已完成建置時，也可執行 `bash start-host.sh --skip-build`。保持終端機開啟；按 Ctrl+C 停止 host 前後端，Piston 容器會繼續運行。

## 第五步：選擇學生端使用方式

### A. 無法安裝桌面程式：另外部署 Online

**先讓 host 保持運行**。若第三步已啟動 host，不需要再啟動一次；請另開第二個終端機，進入本部署工具目錄：

```bash
cd /你的路徑/ntut-exam-env-setup
bash start-online.sh
```

`start-online.sh` 是獨立流程，不會重寫 host 設定或重啟 host／Piston。首次執行時：

1. 讀取 `host/backend/.env` 的管理 Port 與 Token，確認能呼叫 host 管理 API。若連線失敗，先回到第一個終端機確認 host 已就緒。
2. 使用本目錄或同層的 `ntut-exam-online`；找不到時下載 `ntut-exam-online` 的 `main` 分支。既有專案不會自動更新或切換分支。
3. 輸入學生網站 Port（預設 `3003`）、TA 後台 Port（預設 `3004`）、學生可連線的伺服器 IPv4，以及作答檔案保存目錄。兩個 Port 不可彼此重複，也不可與 host 的 Port 重複。
4. 安裝相依套件、建置並啟動。設定保存至 `online-settings.json`，不另存 host Token；每次啟動都會讀取 host 的最新設定。
5. 在主機防火牆允許學生網站的 TCP Port（預設 `3003`）。此指令不會自動設定防火牆。
6. 先用一台學生電腦開啟腳本顯示的 `http://伺服器IP:3003`，確認能讀取題目、上傳與評測，再提供給全班。TA 在主機開啟 `http://127.0.0.1:3004`；自訂 Port 時請替換網址中的數字。

學生網站監聽 `0.0.0.0`，TA 後台只監聽 `127.0.0.1`。考卷與評測設定仍由 host 管理，學生電腦只需要瀏覽器。

online 的日常操作：

```bash
# 沿用設定，重新安裝／建置並啟動
bash start-online.sh

# 已完成建置時快速啟動
bash start-online.sh --skip-build

# 重新設定 Port、IP 與作答保存目錄
bash start-online.sh --configure

# 專案不在預設位置時，每次啟動都需指定路徑
HOST_DIR=/path/to/host ONLINE_DIR=/path/to/ntut-exam-online bash start-online.sh
```

按 Ctrl+C 停止 online，host 與 Piston 繼續運行。若修改 host Token，請先重啟 host，再重新啟動 online。

作答保存目錄預設為 `online-data/target/`；`upload`、`to-judge` 與其他執行資料放在 `online-data/`。若需提供題目附件，請放入 `online-data/exam.zip`，未提供時 `/api/pdf` 回傳 404。`online-data/` 與 `online-settings.json` 均不受 Git 追蹤，請自行備份。

### B. 可安裝桌面程式：準備 Desktop 派送包

1. 取得已建置完成的 desktop Windows 安裝檔，放入 `client-setting/` 並命名為 `ntut-code-tester.exe`；請確認是真正的安裝檔，不是 0-byte 佔位檔。
2. 確認第三步已產生 `client-setting/pre_settings.json`，其中 `remoteHost` 指向伺服器區網 IP 與 **host 學生 API Port**（預設 `3000`）。請以實際設定為準。
3. 將完整 `client-setting/` 資料夾派送至學生電腦，依下方原有指南安裝與啟動。

## 維護：Piston 語言套件

平常重啟服務不需要重新安裝語言套件；套件保存於 Docker named volume `piston-packages`。需要安裝或補充語言時，在部署工具目錄執行：

```bash
# 啟動 Piston 並安裝 Python 與 GCC
bash piston.sh

# 額外安裝指定語言
bash piston.sh python gcc java

# 使用自訂 Piston Port 時，指定與 host 相同的設定
PISTON_PORT=2100 bash piston.sh python gcc
```

### 使用 USB 搬移語言套件

1. 在來源主機安裝所需語言，並確認評測可用。
2. 執行 `bash pack-piston/export.sh`，產生 `pack-piston/piston-packages.tar.gz`。
3. 將壓縮檔複製到 USB，再放入目標主機的 `pack-piston/` 目錄。來源與目標需使用相容的 Docker 平台架構。
4. 首次部署時，在 `setup.sh` 的匯入階段選擇執行；已有環境則先啟動 Piston，再執行 `bash pack-piston/import.sh`。自訂 Port 時使用 `PISTON_PORT=2100 bash pack-piston/import.sh`。
5. 匯入工具會重啟 Piston 並列出可用語言；成功匯入後，可略過線上安裝語言的階段。

本專案的 Piston 容器使用 `privileged`、tmpfs `/piston/jobs` 與 `/tmp`；預設編譯逾時 `30000` 毫秒，輸出上限 `65536` bytes。容器設定請見 `docker-compose.yaml`。

---

## 學生端應用程式 (`desktop`) 派送指南

### 2. 學生電腦遠端控制與派送指南 (使用廣播軟體)

#### 步驟 A：一鍵自動化安裝與環境檢測 (推薦)

將 `client-setting` 資料夾派送到學生電腦（例如桌面），在學生電腦上以管理員身分執行：

```bat
"%USERPROFILE%\Desktop\client-setting\test-deploy-v2.bat"
```

此腳本將自動執行：
1. **執行 `test-v2.ps1` 進行環境測試**：檢測並啟動 VS Code、VMware、Spyder，檢測 C/C++ 編譯器（gcc/g++/clang 指標與記憶體測試）以及 Python 執行環境。
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
