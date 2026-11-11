# Radeon-atieclxx-SSD-Fix

[日本語のヘルプ](HELP.ja.txt) · [英語のヘルプ](HELP.en.txt) · [ドイツ語のヘルプ](LIESMICH.txt) · [フォーク元](https://github.com/necanditool/Radeon-atieclxx-SSD-Fix)

Radeonドライバーの `atieclxx.exe` がシステムドライブに継続して書き込んでいるかを調べるWindows用ツールです。余分な書き込み量を推定でき、既知の自己コピーが原因なら、AMD External Events Utilityを動かしたまま対象ファイルへの書き込みを止められます。

![日本語版でSSDへの継続的な書き込みを検出した画面](docs/screenshot-affected-ja.png)

*診断画面（サンプル値） · [英語版の画面](docs/screenshot-affected-en.png) · [ドイツ語版の画面](docs/screenshot-betroffen.png)*

## ダウンロードと起動

1. [多言語版のZIPをダウンロード](https://github.com/syumari/Radeon-atieclxx-SSD-Fix/archive/refs/heads/main.zip)して、すべて展開します。
2. 展開先の `START.cmd` をダブルクリックします。起動には管理者権限が必要です。

表示はWindowsの表示言語に合わせて、日本語・英語・ドイツ語から自動で選ばれます。未対応の言語では英語になります。管理者権限で開いたPowerShellから一時的に日本語を指定する場合は、展開先で次を実行します。英語は `en`、ドイツ語は `de` を指定します。

```powershell
$env:RADEON_SSD_FIX_LANG = 'ja'
.\START.cmd
```

## どんな問題を調べるのか

2026年11月9日のComputerBaseの記事では、影響を受けるドライバーで `atieclxx.exe` が約1秒ごとに次の場所へ自身をコピーすると報告されています。ファイルは約660 KBで、24時間続くと約56 GBの書き込みになります。[ComputerBaseの記事（ドイツ語）](https://www.computerbase.de/news/grafikkarten/schnelle-ssd-alterung-radeon-treiber-schreibt-fortwaehrend-daten-auf-die-ssd.100237/)

```text
C:\Windows\System32\config\systemprofile\AppData\Local\AMD\atieclxx.exe
```

ツールは書き込み速度を測定し、既知の場所への自己コピー、別の場所への継続的な書き込み、影響なしなどを判定します。SSDへの余分な書き込み量は、測定した速度とAMDグラフィックスの導入後の稼働時間から推定します。SSDから稼働時間を取得できない場合は、1日8時間として計算します。

## 対処方法

| ボタン | 動作 |
| --- | --- |
| **対象ファイルを保護（推奨）** | SYSTEMアカウントによる既知のコピー先への上書き・削除をブロックします。サービスは動作を続けます。 |
| **サービスを無効にする** | AMD External Events Utilityを停止して起動を無効にします。FreeSyncやフレームペーシングに影響する場合があります。 |
| **すべて元に戻す** | ファイル保護と自動チェックを解除し、サービス設定の変更を元に戻します。 |

「Resizable BARとは？」では、元記事で紹介されたBIOS設定による対処を確認できます。設定の変更はBIOSで行います。

![日本語版で対象ファイルを保護した後の画面](docs/screenshot-protected-ja.png)

*保護適用後の画面（サンプル値） · [英語版の画面](docs/screenshot-protected-en.png) · [ドイツ語版の画面](docs/screenshot-geschuetzt.png)*

### ドライバー更新後の自動チェック

対象ファイルを保護すると、タスクスケジューラに `Radeon-atieclxx-SSD-Fix` が登録されます。Windows起動の3分後と、その後30分ごとにSYSTEM権限で動作します。ドライバー更新後も問題が続いていれば保護を再適用し、解消していれば解除します。処理結果は `C:\Program Files\Radeon-atieclxx-SSD-Fix\protokoll.txt` に記録されます。

## 状態確認とアンインストール

| ファイル | 動作 |
| --- | --- |
| `PRUEFEN.cmd` | 状態を表示し、書き込みを10秒間測定します。管理者権限は不要です。 |
| `ENTFERNEN.cmd` | 変更を元に戻し、インストール先のフォルダーを削除します。 |

対象ファイルを保護した後は、どちらのファイルも `C:\Program Files\Radeon-atieclxx-SSD-Fix` に配置されます。

## 技術情報と制約

- 対象ファイルのアクセス制御リストに、SYSTEMによる上書き・削除を拒否するエントリを追加します。
- 自己コピーの検出にはNTFSの変更ジャーナルを使います。必要に応じて短時間のETWトレースで書き込み先を調べます。
- 測定はバックグラウンドで行います。動作にネット接続は不要で、ドライバー本体のファイルは変更しません。ソースコードは [`Skript`](Skript) にあります。
- 署名済みのPowerShellスクリプトしか許可されていない環境では起動できません。Windows Homeなどで `msg.exe` が利用できない場合も、自動チェックの結果はログで確認できます。

## ライセンス

[MITライセンス](LICENSE.txt)で公開しています。AMDとは無関係の非公式ツールです。
