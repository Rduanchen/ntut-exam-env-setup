Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Part 1: Check and Launch Dev Tools" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# 宣告工具偵測變數
$VSCODE_FOUND = $false
$VMWARE_FOUND = $false
$SPYDER_FOUND = $false

Write-Host "[Check] Looking for VS Code..."
$VSCODE_PATH = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
if (Test-Path -LiteralPath $VSCODE_PATH) {
    Write-Host "  -> [OK] Found VS Code, launching..." -ForegroundColor Green
    $VSCODE_FOUND = $true
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start `"`" `"$VSCODE_PATH`"" -WindowStyle Hidden
} else {
    Write-Host "  -> [FAIL] VS Code not found." -ForegroundColor Red
}

Write-Host "`n[Check] Looking for VMware..."
$VMWARE_PATH_1 = "C:\Program Files (x86)\VMware\VMware Workstation\vmplayer.exe"
$VMWARE_PATH_2 = "C:\Program Files (x86)\VMware\VMware Workstation\vmware.exe"
if (Test-Path -LiteralPath $VMWARE_PATH_1) {
    Write-Host "  -> [OK] Found VMware Player, launching..." -ForegroundColor Green
    $VMWARE_FOUND = $true
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start `"`" `"$VMWARE_PATH_1`"" -WindowStyle Hidden
} elseif (Test-Path -LiteralPath $VMWARE_PATH_2) {
    Write-Host "  -> [OK] Found VMware Workstation, launching..." -ForegroundColor Green
    $VMWARE_FOUND = $true
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start `"`" `"$VMWARE_PATH_2`"" -WindowStyle Hidden
} else {
    Write-Host "  -> [FAIL] VMware not found." -ForegroundColor Red
}

Write-Host "`n[Check] Looking for Spyder..."
$SPYDER_PATH = ""
$spyderCommand = Get-Command "spyder.exe" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($spyderCommand) {
    $SPYDER_PATH = $spyderCommand.Source
} else {
    $spyderPaths = @(
        "$env:LOCALAPPDATA\Programs\Spyder\Spyder.exe",
        "$env:LOCALAPPDATA\Spyder\Spyder.exe",
        "$env:ProgramFiles\Spyder\Spyder.exe",
        "$env:USERPROFILE\anaconda3\Scripts\spyder.exe",
        "$env:USERPROFILE\miniconda3\Scripts\spyder.exe",
        "$env:LOCALAPPDATA\anaconda3\Scripts\spyder.exe",
        "$env:LOCALAPPDATA\miniconda3\Scripts\spyder.exe",
        "$env:ProgramData\anaconda3\Scripts\spyder.exe",
        "$env:ProgramData\miniconda3\Scripts\spyder.exe"
    )
    foreach ($path in $spyderPaths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $SPYDER_PATH = $path
            break
        }
    }
}

# Start menu shortcuts also cover standalone and custom Conda installations.
if (-not $SPYDER_PATH) {
    $startMenuPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )
    $spyderShortcut = Get-ChildItem -LiteralPath $startMenuPaths -Filter "Spyder*.lnk" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($spyderShortcut) { $SPYDER_PATH = $spyderShortcut.FullName }
}

if ($SPYDER_PATH) {
    try {
        Start-Process -FilePath $SPYDER_PATH -ErrorAction Stop
        $SPYDER_FOUND = $true
        Write-Host "  -> [OK] Found Spyder, launched: $SPYDER_PATH" -ForegroundColor Green
    } catch {
        Write-Host "  -> [FAIL] Could not launch Spyder: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  -> [FAIL] Spyder not found." -ForegroundColor Red
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "   Part 2: C Compiler Environment Test" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

$CUSTOM_COMPILER_PATH = ""
$COMPILER_FOUND = $false
$COMPILER_PATH = ""
$COMPILER_VERSION = ""
$COMPILER_IN_PATH = $false
$GCC_ENV_STATUS = ""
$COMPILE_SUCCESS = $false
$OVERALL_SUCCESS = $false

$TMPWORK = "$env:TEMP\c_compiler_test_dir"
if (-not (Test-Path -LiteralPath $TMPWORK)) {
    New-Item -ItemType Directory -Path $TMPWORK -Force | Out-Null
}
$TEST_SRC = "$TMPWORK\test_program.c"
$TEST_BIN = "$TMPWORK\test_program.exe"

Write-Host "[Step 1] Detecting C compiler..."
Write-Host "------------------------------------------------------------"

if (-not [string]::IsNullOrWhiteSpace($CUSTOM_COMPILER_PATH)) {
    Write-Host "  -> Using custom path: $CUSTOM_COMPILER_PATH"
    if (Test-Path -LiteralPath $CUSTOM_COMPILER_PATH) {
        $COMPILER_PATH = $CUSTOM_COMPILER_PATH
        $COMPILER_FOUND = $true
        Write-Host "  [OK] Custom compiler found"
    } else {
        Write-Host "  [FAIL] Custom path does not exist" -ForegroundColor Red
    }
}

if (-not $COMPILER_FOUND) {
    Write-Host "  -> Searching system PATH..."
    $compilers = @("gcc.exe","g++.exe","clang.exe","cc.exe","cl.exe")
    foreach ($c in $compilers) {
        $target = Get-Command $c -ErrorAction SilentlyContinue
        if ($target) {
            $COMPILER_PATH = $target.Source
            $COMPILER_FOUND = $true
            $COMPILER_IN_PATH = $true
            Write-Host "  [OK] Found: $COMPILER_PATH"
            break
        }
    }
    if (-not $COMPILER_FOUND) {
        Write-Host "  [FAIL] No compiler in PATH" -ForegroundColor Yellow
    }
} else {
    $COMPILER_IN_PATH = $true
}

Write-Host "`n[Step 2] Environment variable setup"
Write-Host "------------------------------------------------------------"

if (-not $COMPILER_FOUND) {
    Write-Host "  [WARN] Scanning common install paths..." -ForegroundColor Yellow
    $commonPaths = @(
        "C:\MinGW\bin",
        "C:\MinGW64\bin",
        "C:\msys64\mingw64\bin",
        "C:\msys64\mingw32\bin",
        "C:\TDM-GCC-64\bin",
        "C:\TDM-GCC-32\bin",
        "C:\Program Files\LLVM\bin",
        "C:\Program Files (x86)\LLVM\bin",
        "C:\Program Files\CodeBlocks\MinGW\bin"
    )
    $checkExes = @("gcc.exe","g++.exe","clang.exe")
    foreach ($dir in $commonPaths) {
        if ($COMPILER_FOUND) { break }
        foreach ($exe in $checkExes) {
            $fullPath = Join-Path $dir $exe
            if (Test-Path -LiteralPath $fullPath) {
                $COMPILER_PATH = $fullPath
                $COMPILER_FOUND = $true
                $env:PATH = "$dir;" + $env:PATH
                Write-Host "  [OK] Found $exe at $dir, added to session PATH"
                
                # 嘗試永久寫入使用者環境變數
                $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
                if (-not ($userPath -match [regex]::Escape($dir))) {
                    try {
                        $newPath = "$dir;" + $userPath
                        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                        Write-Host "  [OK] Permanently added $dir to User PATH"
                        
                        # 測試 gcc/編譯器 指令是否有反應
                        $testOut = (& "cmd" "/c" "$exe --version" 2>&1) | Out-String
                        if ($LASTEXITCODE -eq 0 -or $testOut -match "version") {
                            $GCC_ENV_STATUS = "SUCCESS"
                            Write-Host "  [OK] '$exe' command tested successfully"
                        } else {
                            $GCC_ENV_STATUS = "FAILED_TEST"
                            Write-Host "  [FAIL] '$exe' command test failed after setting PATH" -ForegroundColor Red
                        }
                    } catch {
                        $GCC_ENV_STATUS = "FAILED_SET"
                        Write-Host "  [FAIL] Could not modify User PATH permanently" -ForegroundColor Red
                    }
                } else {
                    $GCC_ENV_STATUS = "SUCCESS"
                    Write-Host "  [OK] Already in User PATH, but shell restart might be required."
                }
                break
            }
        }
    }
    if (-not $COMPILER_FOUND) {
        Write-Host "  [FAIL] No compiler found in common paths" -ForegroundColor Red
    }
} else {
    Write-Host "  [OK] Compiler already found, no PATH change needed"
}

Write-Host "`n[Step 3] Compiler information"
Write-Host "------------------------------------------------------------"

if ($COMPILER_FOUND) {
    Write-Host "  Location : $COMPILER_PATH"
    try {
        $rawVersion = (& $COMPILER_PATH --version 2>&1) | Out-String
        if ($rawVersion -match "([^\r\n]+)") {
            $COMPILER_VERSION = $Matches[1].Trim()
        } else {
            $COMPILER_VERSION = "Unknown Version Structure"
        }
        Write-Host "  Version  : $COMPILER_VERSION"
    } catch {
        Write-Host "  [WARN] Could not retrieve version." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL] Compiler not found" -ForegroundColor Red
}

Write-Host "`n[Step 4] Generating C test program"
Write-Host "------------------------------------------------------------"

$cSourceCode = @'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Node {
    int value;
    struct Node *next;
} Node;

Node *create_node(int val) {
    Node *n = (Node *)malloc(sizeof(Node));
    if (!n) { fprintf(stderr, "malloc failed\n"); exit(1); }
    n->value = val;
    n->next  = NULL;
    return n;
}

void reverse_array(int *arr, int len) {
    int *left  = arr;
    int *right = arr + len - 1;
    while (left < right) {
        int tmp = *left; *left = *right; *right = tmp;
        left++; right--;
    }
}

typedef int (*CmpFn)(int, int);
int ascending(int a, int b)  { return a - b; }
int descending(int a, int b) { return b - a; }

void bubble_sort(int *arr, int len, CmpFn cmp) {
    for (int i = 0; i < len - 1; i++)
        for (int j = 0; j < len - i - 1; j++)
            if (cmp(arr[j], arr[j+1]) > 0) {
                int tmp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = tmp;
            }
}

char *to_upper(const char *src) {
    int len = strlen(src);
    char *dst = (char *)malloc(len + 1);
    for (int i = 0; i < len; i++)
        dst[i] = (src[i] >= 'a' && src[i] <= 'z') ? src[i] - 32 : src[i];
    dst[len] = '\0';
    return dst;
}

int main(void) {
    printf("=== C Pointer Test ===\n\n");

    printf("[1] Linked List:\n");
    Node *head = NULL, *tail = NULL;
    for (int i = 1; i <= 5; i++) {
        Node *nd = create_node(i * 10);
        if (!head) head = tail = nd;
        else { tail->next = nd; tail = nd; }
    }
    for (Node *cur = head; cur; cur = cur->next)
        printf("  %d%s", cur->value, cur->next ? " -> " : "\n");
    for (Node *cur = head; cur; ) {
        Node *nxt = cur->next; free(cur); cur = nxt;
    }

    printf("\n[2] Array Reverse:\n");
    int arr[] = {1, 2, 3, 4, 5};
    int len = sizeof(arr) / sizeof(arr[0]);
    printf("  Before: "); for (int i=0;i<len;i++) printf("%d ",arr[i]); printf("\n");
    reverse_array(arr, len);
    printf("  After : "); for (int i=0;i<len;i++) printf("%d ",arr[i]); printf("\n");

    printf("\n[3] Function Pointer Sort:\n");
    int data[] = {5, 3, 8, 1, 9, 2};
    int dlen = sizeof(data) / sizeof(data[0]);
    bubble_sort(data, dlen, ascending);
    printf("  Asc : "); for (int i=0;i<dlen;i++) printf("%d ",data[i]); printf("\n");
    bubble_sort(data, dlen, descending);
    printf("  Desc: "); for (int i=0;i<dlen;i++) printf("%d ",data[i]); printf("\n");

    printf("\n[4] String Pointer:\n");
    const char *msg = "hello, world!";
    char *upper = to_upper(msg);
    printf("  Original : %s\n", msg);
    printf("  Upper    : %s\n", upper);
    free(upper);

    printf("\n>>> All pointer tests passed. <<<\n");
    return 0;
}
'@

[System.IO.File]::WriteAllText($TEST_SRC, $cSourceCode, [System.Text.Encoding]::UTF8)
Write-Host "  -> Source: $TEST_SRC"

Write-Host "`n[Step 5] Compiling..."
Write-Host "------------------------------------------------------------"

if ($COMPILER_FOUND) {
    $compileOutFile = "$TMPWORK\compile_out.txt"
    & $COMPILER_PATH -o $TEST_BIN $TEST_SRC -Wall 2> $compileOutFile
    if ($LASTEXITCODE -eq 0) {
        $COMPILE_SUCCESS = $true
        Write-Host "  [OK] Compilation succeeded" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Compilation failed (exit $LASTEXITCODE)" -ForegroundColor Red
        if (Test-Path -LiteralPath $compileOutFile) {
            Get-Content $compileOutFile | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
    }
} else {
    Write-Host "  [SKIP] No compiler available"
}

Write-Host "`n[Step 6] Running test program"
Write-Host "------------------------------------------------------------"

if ($COMPILE_SUCCESS) {
    if (Test-Path -LiteralPath $TEST_BIN) {
        $runOutFile = "$TMPWORK\run_out.txt"
        & $TEST_BIN > $runOutFile 2>&1
        $runExit = $LASTEXITCODE
        Get-Content $runOutFile | ForEach-Object { Write-Host "  | $_" }
        $hasSuccess = Select-String -Path $runOutFile -Pattern "All pointer tests passed" -SimpleMatch
        if ($hasSuccess -and $runExit -eq 0) {
            $OVERALL_SUCCESS = $true
            Write-Host "`n  [OK] All output verified" -ForegroundColor Green
        } else {
            Write-Host "`n  [FAIL] Output check failed (exit $runExit)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  [SKIP] Compilation did not succeed"
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "   Part 3: Python Environment Test" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

$PYTHON_FOUND = $false
$PYTHON_PATH = ""
$PYTHON_VERSION = ""
$PYTHON_IN_PATH = $false
$PYTHON_EXEC_SUCCESS = $false

Write-Host "[Step 1] Detecting Python..."
Write-Host "------------------------------------------------------------"

$pyExes = @("python.exe", "python3.exe", "py.exe")
foreach ($p in $pyExes) {
    $target = Get-Command $p -ErrorAction SilentlyContinue
    if ($target) {
        $PYTHON_PATH = $target.Source
        $PYTHON_FOUND = $true
        $PYTHON_IN_PATH = $true
        Write-Host "  [OK] Found Python in PATH: $PYTHON_PATH"
        break
    }
}

if (-not $PYTHON_FOUND) {
    Write-Host "  [WARN] Searching common Python install paths..." -ForegroundColor Yellow
    $pyDirs = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313",
        "$env:LOCALAPPDATA\Programs\Python\Python312",
        "$env:LOCALAPPDATA\Programs\Python\Python311",
        "$env:LOCALAPPDATA\Programs\Python\Python310",
        "C:\Python313",
        "C:\Python312",
        "C:\Python311",
        "C:\Python310",
        "C:\Program Files\Python313",
        "C:\Program Files\Python312",
        "C:\Program Files\Python311"
    )
    foreach ($dir in $pyDirs) {
        $fullPath = Join-Path $dir "python.exe"
        if (Test-Path -LiteralPath $fullPath) {
            $PYTHON_PATH = $fullPath
            $PYTHON_FOUND = $true
            $env:PATH = "$dir;" + $env:PATH
            Write-Host "  [OK] Found Python at $dir, added to session PATH"
            
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if (-not ($userPath -match [regex]::Escape($dir))) {
                try {
                    $newPath = "$dir;" + $userPath
                    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                    Write-Host "  [OK] Added $dir to User PATH permanently"
                } catch {}
            }
            break
        }
    }
}

if ($PYTHON_FOUND) {
    try {
        $rawPyVer = (& $PYTHON_PATH --version 2>&1) | Out-String
        $PYTHON_VERSION = $rawPyVer.Trim()
        Write-Host "  Location : $PYTHON_PATH"
        Write-Host "  Version  : $PYTHON_VERSION"

        $testPyOut = (& $PYTHON_PATH -c "print('PYTHON_VERIFIED')" 2>&1) | Out-String
        if ($testPyOut -match "PYTHON_VERIFIED") {
            $PYTHON_EXEC_SUCCESS = $true
            Write-Host "  [OK] Python execution test passed" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Python execution test failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FAIL] Error executing Python: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  [WARN] Python not found on machine" -ForegroundColor Yellow
}

Write-Host "`n============================================================"

# 計算狀態文字
$vsText  = "NOT FOUND"; $vsColor = "Red"
if ($VSCODE_FOUND) { $vsText = "FOUND"; $vsColor = "Green" }

$vmText  = "NOT FOUND"; $vmColor = "Red"
if ($VMWARE_FOUND) { $vmText = "FOUND"; $vmColor = "Green" }

$spyderText = "NOT FOUND / LAUNCH FAILED"; $spyderColor = "Red"
if ($SPYDER_FOUND) { $spyderText = "LAUNCHED"; $spyderColor = "Green" }

$sf = if ($COMPILER_FOUND)  { "YES" } else { "NO" }
$sc = if ($COMPILE_SUCCESS) { "PASS" } else { "FAIL" }
$sr = if ($OVERALL_SUCCESS) { "PASS" } else { "FAIL" }

$compileColor = if ($COMPILE_SUCCESS) { "Green" } else { "Red" }
$runColor     = if ($OVERALL_SUCCESS) { "Green" } else { "Red" }

# 輸出橫幅
if ($OVERALL_SUCCESS) {
    Write-Host "  #########################################" -ForegroundColor Green
    Write-Host "  #      ^^^  ALL TESTS PASSED  ^^^       #" -ForegroundColor Green
    Write-Host "  #########################################" -ForegroundColor Green
} else {
    Write-Host "  #########################################" -ForegroundColor Red
    Write-Host "  #     XXX  SOME TESTS FAILED  XXX       #" -ForegroundColor Red
    Write-Host "  #########################################" -ForegroundColor Red
}

# 1. 開發工具狀態報告
Write-Host "`n  [Dev Tools Status]"
Write-Host -NoNewline "  VS Code        : "; Write-Host $vsText -ForegroundColor $vsColor
Write-Host -NoNewline "  VMware         : "; Write-Host $vmText -ForegroundColor $vmColor
Write-Host -NoNewline "  Spyder         : "; Write-Host $spyderText -ForegroundColor $spyderColor

# 2. C 編譯環境狀態報告
Write-Host "`n  [C Environment Status]"
Write-Host "  Compiler Found : $sf"
if ($COMPILER_FOUND) {
    Write-Host "  Location       : $COMPILER_PATH"
    Write-Host "  Version        : $COMPILER_VERSION"
    
    if (-not $COMPILER_IN_PATH) {
        if ($GCC_ENV_STATUS -eq "SUCCESS") {
            Write-Host "  Env Setup      : SUCCESS (Compiler path added to User PATH)" -ForegroundColor Green
        } else {
            Write-Host "  Env Setup      : FAILED - gcc 沒有成功設定，請手動加入環境變數" -ForegroundColor Red
        }
    }
}
Write-Host -NoNewline "  Compile Test   : "; Write-Host $sc -ForegroundColor $compileColor
Write-Host -NoNewline "  Run Verify     : "; Write-Host $sr -ForegroundColor $runColor

# 3. Python 環境狀態報告
Write-Host "`n  [Python Environment Status]"
$pyFoundText = if ($PYTHON_FOUND) { "YES" } else { "NO" }
$pyExecText = if ($PYTHON_EXEC_SUCCESS) { "PASS" } else { "FAIL / NOT FOUND" }
$pyExecColor = if ($PYTHON_EXEC_SUCCESS) { "Green" } else { "Yellow" }
Write-Host "  Python Found   : $pyFoundText"
if ($PYTHON_FOUND) {
    Write-Host "  Location       : $PYTHON_PATH"
    Write-Host "  Version        : $PYTHON_VERSION"
}
Write-Host -NoNewline "  Execute Verify : "; Write-Host $pyExecText -ForegroundColor $pyExecColor

Write-Host "`n============================================================`n"

if (Test-Path -LiteralPath $TMPWORK) {
    Remove-Item -Path $TMPWORK -Recurse -Force -ErrorAction SilentlyContinue
}
