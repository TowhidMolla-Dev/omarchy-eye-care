# omarchy-eye-care

Omarchy シェルプラグイン。眼精疲労対策の **20-20-20ルール** を支援します。

- 20分作業 → 20秒休憩 → 繰り返し (固定値・記事通り厳密運用)
- 休憩時は全画面カウントダウン + デスクトップ通知
- バーに残り時間を表示

## 20-20-20ルールとは

> 20分に1回、20秒間、20フィート (約6m) 離れたところを見る。

出典: [眼精疲労対策（20-20-20ルール）| 古川中央眼科](https://www.eye-care.or.jp/sittoku/%E7%9C%BC%E7%B2%BE%E7%96%B2%E5%8A%B4%E5%AF%BE%E7%AD%96%EF%BC%8820-20-20%E3%83%AB%E3%83%BC%E3%83%AB%EF%BC%89/)

眼精疲労の正体は近くにピントを合わせる筋肉 (主に毛様体筋) の疲労であり、
定期的に遠くを見て休ませることが予防になります。
記事によれば時間・距離は厳密でなくて良く (30分/1時間でも、3mでもやらないより良い)、
大切なのは近くを見る作業を連続させないことです。本プラグインは覚えやすい
20分・20秒の固定値で運用します。

記事で紹介されている米国眼科学会の7つの提案のうち、本プラグインの
メッセージに取り込んでいるもの:

1. 作業中は意識して瞬きする
2. 画面までの距離は腕を伸ばしたくらい (50〜60cm)、画面の高さは目線より下

## 使い方

### ON / OFF (永続・再起動後も維持)

```bash
omarchy plugin disable usutani.eye-care
omarchy plugin enable usutani.eye-care --section right
omarchy plugin list
```

メニューからも可: `Setup > Plugins > Enable / Disable`。

### 一時停止 / 再開 / スキップ (プラグインは入れたまま)

- バーの `󰈈 14:32` を左クリック: 一時停止 / 再開
- バーを右クリック: 今の区間をスキップ (作業中→即休憩、休憩中→即復帰)
- IPC でも可: `omarchy-shell eye-care toggle` / `stop` / `start` / `skip` / `status`

### 休憩 overlay について

20秒のカウントダウンは閉じることができます (カード外クリック・Esc・「作業に戻る」ボタン)。
閉じると次の作業周期に入ります。

## 開発

```bash
# 検証 (公開前に必須)
omarchy plugin validate ~/Work/omarchy-eye-care

# 手動配置 (開発中)
mkdir -p ~/.config/omarchy/plugins/usutani.eye-care
cp ~/Work/omarchy-eye-care/{manifest.json,Service.qml,BarWidget.qml,Overlay.qml} ~/.config/omarchy/plugins/usutani.eye-care/
omarchy-shell shell rescanPlugins
omarchy plugin enable usutani.eye-care --section right
```

短時間での動作確認は以下の手順で行います (20分待たずに休憩動作を確認できます)。

1. 稼働側の `~/.config/omarchy/plugins/usutani.eye-care/Service.qml` を開き、
   `workSeconds` / `restSeconds` を一時的に小さくします (例: 60 / 10)。
   保存するとシェルが自動リロードします (再起動不要)。
2. 次のチェックリストで2周分を確認します。
   - [ ] 作業時間が尽きると通知「目を休めましょう」が出る
   - [ ] 全画面カウントダウン overlay が開く
   - [ ] カウントが 0 になると overlay が閉じて通知「お疲れさまです」が出る
   - [ ] バー表示が作業時間に戻る
   - [ ] overlay のカード外クリック・Esc・「作業に戻る」で中断できる
3. 確認が終わったら値を本番値 (1200 / 20) に戻し、保存して自動リロードさせます。
4. `~/Work/omarchy-eye-care/Service.qml` 側が本番値のままなのを確認します
   (稼働側の一時変更を repo に逆流させないこと)。

## ファイル構成

| ファイル | 役割 |
| --- | --- |
| `manifest.json` | プラグイン定義 (`service` + `bar-widget` + `overlay`) |
| `Service.qml` | タイマー本体 (真実の保持者)。1秒 `Timer` で `work` ⇄ `rest` を遷移 |
| `BarWidget.qml` | バー残時間表示。`shell.serviceFor()` 経由の読み取り専用 + 簡易操作 |
| `Overlay.qml` | 全画面20秒カウントダウン (`PanelWindow`, `WlrLayer.Overlay`) |

## License

MIT
