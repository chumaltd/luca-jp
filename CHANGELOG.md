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
