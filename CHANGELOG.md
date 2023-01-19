## Luca::Jp 0.14.0

* `luca-jp kyuyo --export`: 給与支払報告CSVの実装。lucasalary-jp gemをマージしたもの

## Luca::Jp 0.13.0

* Ruby 3.1との互換性 (Replace YAML.load/load_file to YAML.safe_load)

## Luca::Jp 0.12.4

* 別表四、別表五一、別表五二の還付金算入

## Luca::Jp 0.12.3

* 別表五二の数値表示修正

## Luca::Jp 0.12.2

* 概況説明の試算未設定のエラー対処

## Luca::Jp 0.12.1

* 東京都均等割の明細のフォーマット修正

## Luca::Jp 0.12.0

* `luca-jp chihouzei --export`の出力に地方税申告事務所(jp.eltax.reports.jimusho_name)を追加。未払、未収の追跡用
* 複数自治体をサポートのため`luca-jp chihouzei`の還付税額の計算を`x-customer`にもとづいてフィルタ。

## Luca::Jp 0.11.0

* 課税標準の分割基準の計算(その他業種)
* 事業所数の設定追加
* 均等割額、法人税割税率、所得割税率の自治体別カスタマイズ
* Fix: 地方法人特別税 -> 特別法人事業税

## Luca::Jp 0.10.1

* `--export`が出力する確定税額費用を補助科目に分類
* 別表五二の地方税納税項目を直接計算ではなく伝票を参照する方式に変更

## Luca::Jp 0.10.0

* `--lastyear`オプション追加。会計年度の設定を参照
* 市民税向け事業所名設定追加

## Luca::Jp 0.9.1

* 市町村申請用20号様式の初期実装

## Luca::Jp 0.9.0

* 均等割計算の従業員数設定の追加
* 将来の地方税複数申告のための変更

## Luca::Jp 0.8.1

* 内訳明細書預貯金の摘要

## Luca::Jp 0.8.0

* 別表二の自己株式の計算
* 別表四の事業税仮払経理の減算
* 別表五一の自己株式の計算
* 地方法人税の資本金等の額の計算、税率区分の拡充

## Luca::Jp 0.7.1

* Fix: 資本金等の額の自己株式の額

## Luca::Jp 0.7.0

* 法人事業概況書のconfig拡充
* 勘定科目内訳書(有価証券)の期中金額異動集計

## Luca::Jp 0.6.0

* 別表五一資本金の額の計算の対象科目追加
* Fix: 別表の法人税割金額の100円未満切り捨て

## Luca::Jp 0.5.0

* 地方税確定申告2020/4/1開始年度サポート
* Fix: 資本金等の額
* 提出日の記載

## Luca::Jp 0.4.0

* 法人税確定申告v21.0.2サポート

## Luca::Jp 0.3.0

* 消費税簡易課税申告v20.0.1サポート
* Fix: 消費税申告区分

## Luca::Jp 0.2.4

* Fix: 地方税六号様式の法人税割計算の基礎となる法人税額

## Luca::Jp 0.2.3

* Fix: 別表五一期中減、別表五二事業税中間納付

## Luca::Jp 0.2.2

* Fix: Include Common from Syouhizei

## Luca::Jp 0.2.1

* implement additional fields

## Luca::Jp 0.2.0

* implement 概況説明 config
* implement 買掛金内訳明細、借入金内訳明細、地代家賃内訳明細、有価証券内訳明細

## Luca::Jp 0.1.8

* implement 別表二 template
* implement `luca-jp urikake` for LucaDeal

## Luca::Jp 0.1.7

* implement USERINF template

## Luca::Jp 0.1.6

* refine 別表四、別表5-1、別表5-2

## Luca::Jp 0.1.5

* 未収還付は損金の戻り益金ではないため所得計算から還付事業税を除外
* 別表5-2の期末未収税金の記載

## Luca::Jp 0.1.4

* 繰越損失管理の初期実装。別表7 / 6号様式別表9

## Luca::Jp 0.1.3

* config-lucajp.ymlを追加ロード。LucaBookとconfigを分割可能
* IT部にeltax_idを追加

## Luca::Jp 0.1.2

* 別表4, 別表5-2の中間納付の内訳を実装。仮払税金を分類できていることが条件
* 確定税額は、法人税と地方税を一括計算するロジックを導入
* 法人税割と均等割の関数の戻り値を都道府県と市に分割
* IT部をconfigから生成

## Luca::Jp 0.1.1

* 法人税、消費税、地方税の計算
* etax, eltax用XML生成
