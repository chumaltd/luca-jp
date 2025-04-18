# 法人税申告用Config

configはLucaBookの`config.yml`に加えて、Luca::Jp専用の`config-lucajp.yml`をロードする。  
各年度特有の調整項目などは、[単年度用Config](./config-yearly.md)を参照。

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
| total_votes  |         | 期末現在の議決権の総数                    |   |
| own_shares   |         | 自己株式の総数                            |   |
| no_votes     |         | 議決権行使不能株式の総数                  |   |
| owners       |         | 株主のリスト(配列)。記載順で上位3位を計算 |   |
|              | name    | 株主の名称                                |   |
|              | address | 株主の住所                                |   |
|              | shares  | 持株数                                    |   |
|              | votes   | 保有議決権数                              |   |


勘定科目内訳明細書
------------

勘定科目内訳明細書のうち、取引先情報や預金口座などは補助科目のconfigを参照する。`jp.accounts`以下に補助科目の配列を定義する。

| key              | Description                        | Must | Only for         |
|------------------|------------------------------------|------|------------------|
| code             | 補助科目コード                     | ✔    |                  |
| name             | 取引先名称または銀行名             | ✔    |                  |
| tax_id           | インボイス登録番号                 |      | 買掛金・地代家賃 |
| address          | 取引先住所                         |      |                  |
| note             | 摘要欄既述                         |      |                  |
| branch           | 支店名                             |      | 預金口座用       |
| account_type     | 預金種別。無指定の場合、普通預金   |      | 預金口座用       |
| account_no       | 口座番号                           |      | 預金口座用       |
| rent_type        | 地代または家賃。無指定の場合、家賃 |      | 地代家賃用       |
| rent_purpose     | 借地借家の用途                     |      | 地代家賃用       |
| rent_address     | 借地借家の住所                     |      | 地代家賃用       |
| security_purpose | 売買／満期／その他                 |      | 有価証券用       |
| security_genre   | 株式、債券など                     |      | 有価証券用       |
| security_units   | 保有数量                           |      | 有価証券用       |


法人事業概況説明書
------------

法人事業概況説明書は、`jp.gaikyo`以下のconfig参照項目がある。

| key               | Description                                                 |            |
|-------------------|-------------------------------------------------------------|------------|
| homepage          | ホームページのURL                                           |            |
| shiten_kokunai    | 国内の支店数                                                |            |
| shiten_kaigai     | 海外の支店数                                                |            |
| kogaisha_kokunai  | 国内の子会社数                                              |            |
| kogaisha_kaigai   | 海外の子会社数                                              |            |
| yunyu             | 輸入取引                                                    | true/false |
| yushutsu          | 輸出取引                                                    | true/false |
| kaigai_torihiki   | 輸出入以外の海外取引                                        | true/false |
| yakuin            | 常勤役員の人数                                              |            |
| chingin_kotei     | 固定給                                                      | true/false |
| chingin_buai      | 歩合給                                                      | true/false |
| shataku           | 社宅・寮                                                    | true/false |
| windows           | Windows利用                                                 | true/false |
| mac               | Mac利用                                                     | true/false |
| linux             | Linux利用                                                   | true/false |
| pc_kyuuyo         | PC利用 給与管理                                             | true/false |
| pc_hanbai         | PC利用 在庫・販売管理                                       | true/false |
| pc_seisan         | PC利用 生産管理                                             | true/false |
| software_kaikei   | 会計ソフトの名称                                            |            |
| software_mail     | メールソフトの名称                                          |            |
| ec_uriage         | 電子商取引・売上                                            | true/false |
| ec_shiire         | 電子商取引・仕入                                            | true/false |
| ec_keihi          | 電子商取引・経費                                            | true/false |
| ec_jisha          | 電子商取引・売上 自社HP                                     | true/false |
| ec_tasha          | 電子商取引・売上 他社HP                                     | true/false |
| genkin_kanrisha   | 現金管理者氏名                                              |            |
| tsucho_kanrisha   | 通帳管理者氏名                                              |            |
| shisanhyou        | 試算表作成頻度(月単位の間隔で指定。1は毎月、12は決算時のみ) | 1 - 12     |
| gensen_rishi      | 源泉徴収 利子等                                             | true/false |
| gensen_haitou     | 源泉徴収 配当                                               | true/false |
| gensen_hikyoju    | 源泉徴収 非居住者                                           | true/false |
| gensen_taishoku   | 源泉徴収 退職                                               | true/false |
| keiri_zeinuki     | 経理方式 税抜                                               | true/false |
| keiri_zeikomi     | 経理方式 税込                                               | true/false |
| kansa             | 社内監査実施                                                | true/false |
| genkin_share      | 現金売上の割合(%)                                           |            |
| kake_share        | 掛売上の割合(%)                                             |            |
| shimekiri         | 締切日(共通指定)                                            |            |
| shimekiri_uriage  | 売上の締切日                                                |            |
| shimekiri_shiire  | 仕入の締切日                                                |            |
| shimekiri_gaichu  | 外注の締切日                                                |            |
| shimekiri_kyuryou | 給料の締切日                                                |            |
| kessai            | 決済日(共通指定)                                            |            |
| kessai_uriage     | 売上の決済日                                                |            |
| kessai_shiire     | 仕入の決済日                                                |            |
| kessai_gaichu     | 外注の決済日                                                |            |
| kessai_kyuryou    | 給料の決済日                                                |            |

### 改訂により廃止された項目

| key               | Description                                                 |            |
|-------------------|-------------------------------------------------------------|------------|
| data_cloud        | クラウドにデータ保存                                        | true/false |
| data_media        | 外部記憶媒体にデータ保存                                    | true/false |
| data_server       | PCサーバにデータ保存                                        | true/false |


USERINF
------------

地方税の納税者情報は概ねIT部の設定を参照するが、地方税特有の設定は`jp.eltax`以下に記載する。  
eltax仕様では法人番号は省略可能フィールドであり、法人番号から各種の自治体管理IDを参照する機能はないと見られる。

```yaml
jp:
  eltax:
    reports:
    - jimusho_name: 東京都芝都税事務所長
    - jimusho_name: 東京都渋谷都税事務所長
```

| key       | subkey         | Description                                                                                                  | eltaxフィールド |
|-----------|----------------|--------------------------------------------------------------------------------------------------------------|-----------------|
| no_keigen |                | 軽減税率不適用法人。[true / false]                                                                           |                 |
| reports   |                | 申告書提出先の設定(配列)                                                                                     |                 |
|           | type           | prefecture / city / 23ku                                                                                     |                 |
|           | jichitai_code  | 地方公共団体コード                                                                                           | ORG1_CD         |
|           | jimusho_code   | 都道府県税事務所番号                                                                                         | JIMUSHO_NUM     |
|           | jimusho_name   | 提出先名称。elTaxは事務所番号からひくことができない                                               | ORG1_NAME       |
|           | x_houjin_bango | 地方自治体がかつて使用していた旧法人番号。必須                                                               | KAZEI_NUM       |
|           | name           | 事務所名。省略時は「本店」                                                                                   |                 |
|           | address        | 事務所所在地。省略時は`it_part.nozeisha_adr`を参照                                                           |                 |
|           | employee       | 従業員の数                                                                                                   |                 |
|           | office_count | 事業所の数。省略時は1                                                                                                  |                 |
|           | kintouwari | 均等割税額                                                                                                   |                 |
|           | houjinzeiwari | 法人税割税率                                                                                                   |                 |
|           | shotoku399 | 所得割税率。400万円以下の部分                                                                                                |                 |
|           | shotoku401 | 所得割税率。400万円超800万円以下の部分                                                                                             |                 |
|           | shotoku801 | 所得割税率。800万円超の部分                                                                                             |                 |
|           | receipt_num    | eLtaxのID。ログインIDではなく、通常使用することはない文字列                                                  | T_RCPT_NUM      |
|           | app_version    | 税目情報格納日時(申請バージョン)。条例改定のつど変わると考えられ、PCDeskの出力ファイルから取得する必要がある | STIME           |

