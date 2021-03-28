# Luca::Jp

[LucaBook](https://github.com/chumaltd/luca/blob/master/lucabook/)の法人税・消費税・地方税申告用エクステンション

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'luca-jp'
```

And then execute:

```bash
$ bundle
```

## Usage

`luca-jp`コマンドに期間指定してeTax用のxtxまたはeLtax用のXMLを出力。

```bash
$ luca-jp [houjinzei|syouhizei] yyyy mm yyyy mm > tax.xtx
$ luca-jp chihouzei yyyy mm yyyy mm > tax.xml

# exportオプションはLucaBookインポート用の仕訳を出力
$ luca-jp [houjinzei|syouhizei|chihouzei] yyyy mm yyyy mm --export > export.json
```

LucaBookの日本用標準勘定科目を利用した仕訳データを前提としている。税務署は内訳データを求めているため、税金納付などは種目を細かく分類して記帳しなくてはならない。

* 中間納付の計算上、最終月は計算から除外する。決算仕訳により相殺される影響を受けない


## Config

configはLucaBookの`config.yml`に加えて、Luca::Jp専用の`config-lucajp.yml`をロードする。

IT部
------------

納税者情報は、`jp.it_part`以下に記載する。複数の要素を持つ項目は`-`区切りで記述。  
eTaxソフトが拒否する文字がありうるため、eTaxソフトで作成したデータのドラフトを「切り出し」したxtxファイルからコピーした方が安全。

```yaml
jp:
  it_part:
    zeimusho: 01109-芝
```

| key              |              Description |   |
|------------------|--------------------------|---|
| zeimusho         |                code-name |   |
| nozeisha_id      |                          |   |
| nozeisha_bango   |                          |   |
| nozeisha_zip     |                 100-1000 |   |
| nozeisha_nm_kn   |                          |   |
| nozeisha_nm      |                          |   |
| nozeisha_adr_kn  |                          |   |
| nozeisha_adr     |                          |   |
| nozeisha_tel     |             03-0000-0000 |   |
| shihon_kin       |                          |   |
| jigyo_naiyo      |                          |   |
| daihyo_zip       |                 100-1000 |   |
| daihyo_nm_kn     |                          |   |
| daihyo_nm        |                          |   |
| daihyo_adr       |                          |   |
| daihyo_tel       |                          |   |
| keiri_sekininsha |                          |   |
| kanpu_kinyukikan | 銀行名-支店名-1-口座番号 |   |
| eltax_id         |                          |   |

別表二
------------

別表二は、`jp.beppyo2`以下のconfigに基いて生成する。

| key          | subkey  | Description                               |   |
|--------------|---------|-------------------------------------------|---|
| total_shares |         | 期末現在の発行済株式の総数又は出資の総額  |   |
| total_votees |         | 期末現在の議決権の総数                    |   |
| owners       |         | 株主のリスト(配列)。記載順で上位3位を計算 |   |
|              | name    | 株主の名称                                |   |
|              | address | 株主の住所                                |   |
|              | shares  | 持株数                                    |   |
|              | votes   | 保有議決権数                              |   |


勘定科目内訳明細書
------------

勘定科目内訳明細書のうち、取引先情報や預金口座などは補助科目のconfigを参照する。`jp.accounts`以下に補助科目の配列を定義する。

| key          | Description                        | Must | Only for   |
|--------------|------------------------------------|------|------------|
| code         | 補助科目コード                     | ✔    |            |
| name         | 取引先名称または銀行名             | ✔    |            |
| address      | 取引先住所                         |      |            |
| note         | 摘要欄既述                         |      |            |
| branch       | 支店名                             |      | 預金口座用 |
| account_type | 預金種別。無指定の場合、普通預金   |      | 預金口座用 |
| account_no   | 口座番号                           |      | 預金口座用 |
| rent_type    | 地代または家賃。無指定の場合、家賃 |      | 地代家賃用 |
| rent_purpose | 借地借家の用途                     |      | 地代家賃用 |
| rent_address | 借地借家の住所                     |      | 地代家賃用 |


法人事業概況説明書
------------

法人事業概況説明書は、`jp.gaikyo`以下のconfig参照項目がある。

| key              | Description       |   |
|------------------|-------------------|---|
| homepage         | ホームページのURL |   |
| shiten_kokunai   | 国内の支店数      |   |
| shiten_kaigai    | 海外の支店数      |   |
| kogaisha_kokunai | 国内の子会社数    |   |
| kogaisha_kaigai  | 海外の子会社数    |   |
| genkin_kanrisha  | 現金管理者氏名    |   |
| tsucho_kanrisha  | 通帳管理者氏名    |   |
| genkin_share     | 現金売上の割合(%) |   |
| kake_share       | 掛売上の割合(%)   |   |


USERINF
------------

地方税の納税者情報は概ねIT部の設定を参照するが、地方税特有の設定は`jp.eltax`以下に記載する。  
eltax仕様では法人番号は省略可能フィールドであり、法人番号から各種の自治体管理IDを参照する機能はないと見られる。

```yaml
jp:
  eltax:
    jimusho_name: 東京都芝都税事務所長
```

| key            | Description                                                                                                  | eltaxフィールド |
|----------------|--------------------------------------------------------------------------------------------------------------|-----------------|
| jimusho_code   | 都道府県税事務所番号                                                                                         | JIMUSHO_NUM     |
| jimusho_name   | elTaxは都道府県税事務所番号から提出先名称をひくことができない                                                | ORG1_NAME       |
| receipt_num    | eLtaxのID。ログインIDではなく、通常使用することはない文字列                                                  | T_RCPT_NUM      |
| shihon         | 資本金と資本準備金の合計額。様式6に記載                                                                      | SHIHON          |
| x_houjin_bango | 地方自治体がかつて使用していた旧法人番号。必須なのではないかと思われる                                       | KAZEI_NUM       |
| app_version    | 税目情報格納日時(申請バージョン)。条例改定のつど変わると考えられ、PCDeskの出力ファイルから取得する必要がある | STIME           |


## Format

各種書類に出力するデータは会計により出力可能な範囲に限り、eTaxソフトなどで追加編集のうえ提出。また、特定の法人を前提としている

法人税
---------

* 別表1
* 別表1次葉
* 別表2
  * 別表２のconfigを参照
* 別表4
  * 中間納付金額は損金経理による納付となり、うち仮払還付額は仮払税金認定損
  * 還付受け入れは前期仮払税金否認となり、一部は法人税等の中間納付額及び過誤納に係る還付金額等(AOD00130)となる
* 別表5-1
  * 確定税額のうち中間納付に対応しない未納額から納税充当金(ICB00460)を算出
* 別表5-2
  * 未払法人税、未払都道府県住民税、未払市民税、未払地方事業税、未払消費税等を期首残高・納税充当金納付として参照
  * 未収法人税、未収都道府県住民税、未収市民税、未収地方事業税、未収消費税等を期首還付残高・仮払い納付(マイナス計上)として参照
  * 仮払法人税、仮払法人税(地方)、仮払地方税特別法人事業税、仮払地方税所得割、仮払都道府県民税法人税割、仮払都道府県民税税均等割、仮払消費税、仮払地方消費税、仮払市民税法人税割、仮払市民税均等割を中間納付・仮払い納付／損金納付として参照
* 別表7
* 別表15
* 適用額明細書
* 事業概況報告書
  * 事業概況報告書のconfigを参照
* 預貯金の勘定科目内訳書
  * 現金及び預金の補助科目につき、configで口座情報を設定
* 買掛金の勘定科目内訳書
  * 買掛金、未払金、未払費用の期末残高を参照
  * 買掛金、未払金、未払費用の補助科目につき、configで取引先を設定
* 仮受金の勘定科目内訳書
* 借入金の勘定科目内訳書
  * 短期借入、長期借入の期末残高を参照
  * 短期借入、長期借入の補助科目につき、configで取引先を設定
* 地代家賃の勘定科目内訳書
  * 地代家賃の補助科目につき、configで取引先、物件情報を設定
* 役員報酬の勘定科目内訳書

XBRL2.1決算書は、LucaBookが出力可能。xtxをインポートしたのち、XBRL2.1財務書評を追加するとインポートできる。  
税務会計のローカルルールに対応するため、日本語のデフォルト辞書はeTaxのタクソノミーを用いており、販売管理費の内訳を出力する。

少額減価償却資産はサポートしていない。eTaxソフトで、別表と対応する適用額明細を追加する。


消費税
---------

* 簡易課税申告書
* 付表4-3
* 付表5-3


地方税
---------

* 6号様式
* 均等割に関する明細書
* 6号様式別表9
