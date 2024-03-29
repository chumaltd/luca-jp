# 申告フォーマット

各種書類に出力するデータは会計により出力可能な範囲に限り、eTaxソフトなどで追加編集のうえ提出。また、特定の法人を前提としている

法人税
---------

* 別表1
* 別表1次葉
* 別表2
  * 別表２のconfigを参照
* 別表4
  * 中間納付金額は損金経理による納付となり、うち仮払還付額は仮払税金認定損
  * 中間納付金額に還付があるケースでも期末で確定し、損益に影響がない想定
* 別表5-1
  * 確定税額のうち中間納付に対応しない未納額から納税充当金(ICB00460)を算出
* 別表5-2
  * 未払法人税、未払都道府県住民税、未払市民税、未払地方事業税、未払消費税等を期首残高・納税充当金納付として参照
  * 未収法人税、未収都道府県住民税、未収市民税、未収地方事業税、未収消費税等を期首還付残高・仮払い納付(マイナス計上)として参照
  * 仮払法人税、仮払法人税(地方)、仮払地方税特別法人事業税、仮払地方税所得割、仮払都道府県民税法人税割、仮払都道府県民税税均等割、仮払消費税、仮払地方消費税、仮払市民税法人税割、仮払市民税均等割を中間納付・仮払い納付／損金納付として参照
  * 地方税の中間納付はLucaBookの納付データが自治体ごとに分類されている必要がある(`x-custoer` に `jp.eltax.reports.jimusho_name` を指定)
* 別表7
* 別表15

* 適用額明細書
  * 中小企業の軽減税率を判定
  * 少額減価償却資産はサポートしていない。eTaxソフトで、別表と対応する適用額明細を追加する。
* 事業概況報告書
  * 事業概況報告書のconfigを参照

* 預貯金の内訳書
  * 現金及び預金の補助科目につき、configで口座情報を設定
* 有価証券の内訳書
  * 投資有価証券、関係会社株式の期末残高を参照
  * 投資有価証券、関係会社株式の補助科目につき、configで取引先を設定
* 買掛金の内訳書
  * 買掛金、未払金、未払費用の期末残高を参照
  * 買掛金、未払金、未払費用の補助科目につき、configで取引先を設定
* 仮受金の内訳書
* 借入金の内訳書
  * 短期借入、長期借入の期末残高を参照
  * 短期借入、長期借入の補助科目につき、configで取引先を設定
* 地代家賃の内訳書
  * 地代家賃の補助科目につき、configで取引先、物件情報を設定
* 役員報酬の内訳書
  * 代表者情報はIT部の設定を参照
* 雑益雑損失の内訳書
  * 雑収入、雑損失の各仕訳を参照
  * 雑収入、雑損失の補助科目の期末残高を参照
* 売掛金の内訳書
  * `luca-jp urikake`コマンドでCSV出力
  * LucaDealで入金追跡できている必要あり

XBRL2.1決算書は、LucaBookが出力可能。xtxをインポートしたのち、XBRL2.1財務書評を追加するとインポートできる。  
税務会計のローカルルールに対応するため、日本語のデフォルト辞書はeTaxのタクソノミーを用いており、販売管理費の内訳を出力する。

以下の勘定科目内訳書は個別集計が必要であるため、サポートしていない。  
別途CSV作成のうえ、eTaxソフトで「組み込み」操作する方法が現実的といえる。

* 受取手形の内訳書
* 支払手形の内訳書
* 仮払金(前渡金)の内訳書、貸付金及び受取利息の内訳書
* 借入金及び支払利子の内訳書
* 棚卸資産(商品又は製品、半製品、仕掛品、原材料、貯蔵品)の内訳書
* 固定資産(土地、土地の上に存する権利及び建物に限る。)の内訳書
* 土地の売上高等の内訳書
* 売上高等の事業所別内訳書


消費税
---------

* 簡易課税申告書
* 付表4-3
* 付表5-3


地方税
---------

* 6号様式
  * 「決算確定の日」などは追記が必要。未入力の場合、署名リストに表示されない
  * 所得金額の計算のうち、地方税ルールの加算減算は考慮していない
  * 外形標準課税法人や特別法人を適切に扱っていない
  * 修正申告を想定していない
  * 中間納付はLucaBookの納付データが自治体ごとに分類されている必要がある(`x-custoer` に `jp.eltax.reports.jimusho_name` を指定)
* 均等割に関する明細書
* 6号様式別表9
* 20号様式
  * 実ケースがないため未検証
  * 政令区を考慮していない
