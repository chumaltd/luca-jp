# 申告フォーマット

各種書類に出力するデータは会計により出力可能な範囲に限り、eTaxソフトなどで追加編集のうえ提出。また、特定の法人を前提としている

法人税
---------

報告を求められている公金類は、LucaBookの日本の補助科目をあらかじめ予約のうえ集計している。  
他の内訳明細対象科目も対応する額を参照し、必要に応じてConfig指定した補助科目から明細を出力する。

* 別表1
  * 税額控除欄は、所得税の仮払科目(185F)を参照
* 別表1次葉
* 別表2
  * 別表２のconfigを参照
* 別表4
  * 中間納付金額は損金経理による納付となり、うち仮払還付額は仮払税金認定損
  * 中間納付金額に還付があるケースでも期末で確定し、損益に影響がない想定
  * 加算・減算欄の益金・損金調整額は、[単年度config](./config-yearly.md)を参照
* 別表5-1
  * 確定税額のうち中間納付に対応しない未納額から納税充当金(ICB00460)を算出
* 別表5-2
  * 未払法人税(5151)、未払都道府県住民税(5153)、未払市民税(5154)、未払地方事業税(5152)、未払消費税等(516)を期首残高・納税充当金納付として参照
  * 未収法人税(1502)、未収都道府県住民税(1503)、未収市民税(1505)、未収地方事業税(1504)、未収消費税等(1501)を期首還付残高・仮払い納付(マイナス計上)として参照
  * 仮払法人税(1851)、仮払法人税(地方)(1852)、仮払地方税特別法人事業税(1854)、仮払地方税所得割(1855)、仮払都道府県民税法人税割(1859)、仮払都道府県民税税均等割(185A)、仮払消費税(1841)、仮払地方消費税、仮払市民税法人税割(185D)、仮払市民税均等割(185E)を中間納付・仮払い納付／損金納付として参照
  * 地方税の中間納付はLucaBookの納付データが自治体ごとに分類されている必要がある(`x-custoer` に `jp.eltax.reports.jimusho_name` を指定)
* 別表6-1
  * 所得税の仮払科目(185F)を参照
* 別表7
  * 別表4で計算した当期損失と繰越損失レコードを参照
* 別表8-1
  * [単年度config](./config-yearly.md)の受取配当金の益金不算入額を参照
* 別表14-2
  * 寄付金(C1X)、指定寄付金(C1X1)の科目を参照。指定寄付金は全額損金として扱い、それ以外の寄付金額は限度額を考慮する
* 別表15
  * 交際費(C1B)を参照。飲食の計算は未実装

* 適用額明細書
  * 中小企業の軽減税率を判定
  * 少額減価償却資産はサポートしていない。eTaxソフトで、別表と対応する適用額明細を追加する。
* 事業概況報告書
  * 事業概況報告書のconfigを参照

* 預貯金の内訳書
  * 現金及び預金の補助科目につき、configで口座情報を設定
* 有価証券の内訳書
  * 投資有価証券(331)、関係会社株式(332)の期末残高を参照
  * 投資有価証券、関係会社株式の補助科目につき、configで保有銘柄を設定
* 買掛金の内訳書
  * 買掛金(511)、未払金(514)、未払費用(517)の期末残高を参照
  * 買掛金、未払金、未払費用の補助科目につき、configで設定した取引先を明細出力
* 仮受金の内訳書
  * 所得税源泉給与(5191)、所得税士業(5193)、所得税源泉報酬(5194)を参照
* 借入金の内訳書
  * 短期借入(512)、長期借入(712)の期末残高を参照
  * 短期借入、長期借入の補助科目につき、configで取引先を設定
  * 支払い利子の計算は未実装。該当する場合には追記が必要
* 地代家賃の内訳書
  * 地代家賃(C1E)の補助科目につき、configで取引先、物件情報を設定
* 役員報酬の内訳書
  * 代表者情報はIT部の設定を参照
  * 総額は役員報酬(C11)・給料手当(C12)の集計額を参照
* 雑益雑損失の内訳書
  * 雑収入(D16)、雑損失(E16)の各仕訳を参照
  * 雑収入、雑損失の補助科目の期末残高を参照
* 売掛金の内訳書
  * `luca-jp urikake`コマンドでCSV出力
  * LucaDealで入金追跡できている必要あり

XBRL決算書は税務会計のローカルルールに対応するため、日本語のデフォルト辞書はeTaxのタクソノミーを用いており、販売管理費の内訳を出力する。

以下の勘定科目内訳書は個別集計が必要であるため、サポートしていない。  
別途CSV作成のうえ、eTaxソフトで「組み込み」操作する方法が現実的といえる。

* 受取手形の内訳書
* 支払手形の内訳書
* 仮払金(前渡金)の内訳書、貸付金及び受取利息の内訳書
* 棚卸資産(商品又は製品、半製品、仕掛品、原材料、貯蔵品)の内訳書
* 固定資産(土地、土地の上に存する権利及び建物に限る。)の内訳書
* 土地の売上高等の内訳書
* 売上高等の事業所別内訳書


消費税
---------

* 簡易課税申告書
* 付表4-3
* 付表5-3
* 付表6
  * `jp.syouhizei_kubun: 2023`を指定した場合に生成。2割特例の申告書


地方税
---------

* 6号様式
  * 所得金額の計算のうち、地方税ルールの加算減算は考慮していない
  * 外形標準課税法人や特別法人を適切に扱っていない
  * 修正申告を想定していない
  * 中間納付はLucaBookの納付データが自治体ごとに分類されている必要がある(`x-custoer` に `jp.eltax.reports.jimusho_name` を指定)
* 均等割に関する明細書
* 6号様式別表9
* 20号様式
  * 実ケースがないため未検証
  * 政令区を考慮していない
