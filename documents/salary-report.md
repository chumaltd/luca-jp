# 給与支払報告用フィールド

従業員プロフィール(profiles)
------------

profiles/とs_profiles/のレコードを統合する。s_profilesのレコードを暗号化して保持する想定。  
申告上の年齢区分は生年月日から計算。

| key        | subkey     | Description              |
|------------|------------|--------------------------|
| address    |            | 住所                     |
| address2   |            | 住所の続き               |
| katakana   |            | 本人の氏名フリガナ       |
| birth_date |            | 本人の生年月日(YYYY-M-D) |
| tax_id     |            | 本人の個人番号           |
| spouse     |            | 控除対象配偶者           |
|            | name       | 氏名                     |
|            | katakana   | 氏名フリガナ             |
|            | birth_date | 生年月日(YYYY-M-D)       |
|            | tax_id     | 個人番号                 |
| family     |            | 扶養対象親族（配列）     |
|            | name       | 氏名                     |
|            | katakana   | 氏名フリガナ             |
|            | birth_date | 生年月日(YYYY-M-D)       |
|            | tax_id     | 個人番号                 |
| resident   |            | 住民税の情報             |
|            | area_code  | 自治体コード             |
|            | tax_id     | 自治体が発行する指定番号 |
|            | extra      | 6月の住民税金額          |
|            | ordinal    | 6月以外の住民税金額      |


年末調整レコード(payments/total/)
------------

扶養控除等申告書の各年設定を記録

| key    | subkey | Description    |
|--------|--------|----------------|
| spouse |        | 控除対象配偶者 |
|        | income | 本年の合計所得 |
