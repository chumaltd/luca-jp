# Luca::Jp

![Gem Version](https://badge.fury.io/rb/luca-jp.svg)
[![doc](https://img.shields.io/badge/doc-rubydoc-green.svg)](https://www.rubydoc.info/gems/luca-jp/index)
![license](https://img.shields.io/github/license/chumaltd/luca-jp)

[LucaBook](https://github.com/chumaltd/luca/blob/master/lucabook/)の法人税・消費税・地方税申告用エクステンションと[LucaSalary](https://github.com/chumaltd/luca/blob/master/lucasalary/)の所得税エクステンション

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'luca-jp'
```

And then execute:

```bash
$ bundle
```

### 前提条件

給与支払報告が半角カナを求めるため、CSV生成(`luca-jp kyuyo --export`)に`uconv`コマンドが必要。  
Debian系の場合、icu-devtoolsパッケージに含まれる。


Documents
---------

* [法人税申告用Config](./documents/config.md)
* [申告フォーマット](./documents/report-format.md)
* [給与支払報告用フィールド](./documents/salary-report.md)

### 開発用情報

* [資料](documents/resources.md)


Usage
---------

`luca-jp`コマンドは税額計算、仕訳データ、申告データを生成。

申告用のXML生成に先立って、`--export`オプションで確定税額の仕訳を生成し、LucaBookにインポートしておく。  
仕訳を一式インポートしたうえで、`luca-jp`コマンドでeTax用のxtxまたはeLtax用のXMLを出力。


### 消費税の計算

消費税課税事業者は、`luca-jp syouhizei --export`を最初に実行する。

```bash
# LucaBookのディレクトリトップで実行する
$ cd </path/to/project-dir>

# exportオプションはLucaBookインポート用の仕訳を出力
$ luca-jp syouhizei --export [--lastyear|<yyyy> <mm> <yyyy> <mm>] > <export.json>
$ cat <export.json> | luca-book journals import --json

$ luca-jp syouhizei [--lastyear|<yyyy> <mm> <yyyy> <mm>] > <tax.xtx>
```

### 法人税・地方税の計算

```bash
# LucaBookのディレクトリトップで実行する
$ cd </path/to/project-dir>

# exportオプションはLucaBookインポート用の仕訳を出力
$ luca-jp [houjinzei|chihouzei] --export [--lastyear|<yyyy> <mm> <yyyy> <mm>] > <export.json>
$ cat <export.json> | luca-book journals import --json

$ luca-jp houjinzei [--lastyear|<yyyy> <mm> <yyyy> <mm>] > <tax.xtx>
# 地方税はchihouzei-<jimusho_code>.xmlを出力
$ luca-jp chihouzei [--lastyear|<yyyy> <mm> <yyyy> <mm>]
```

`-x path/to/extra-conf.yml`オプションを追加することで、単期のconfigセットを指定できる。ファイル名は任意。仕訳データ生成時と申告書ファイル生成時に同一のconfigファイルを指定しなくてはならない。

各XMLファイルは、eTax/PCDeskにインポートする。

* xtxファイルはeTaxソフトの「作成」->「申告・申請等」->「組み込み」からインポート可能
* 地方税のxmlファイルはPCDeskの「申告データ一覧(照会・編集)」->「取り込み」からインポート可能

LucaBookの日本用標準勘定科目を利用した仕訳データを前提としている。税務署は内訳データを求めているため、税金納付などは種目を細かく分類して記帳しなくてはならない。

* 多くの項目を自動生成するが、仕訳から明細を生成できない項目は残る。eTaxソフトで確認のうえ修正する。注意事項は`luca-jp`コマンド実行時にコンソールの標準エラーに表示。
* 中間納付の計算上、最終日の仕訳を計算から除外する。決算仕訳により相殺される影響を受けない


### 財務諸表

`luca-book`がXBRL2.1の財務諸表を出力する。

```bash
$ luca-book report xbrl <yyyy> <mm> <yyyy> <mm>
```

eTaxソフトで「帳票追加」->「財務諸表(XBRL2.1)」を追加したうえで、財務諸表編集画面から「組み込み」可能。  
xbrl(財務データ)とxsd(企業別タクソノミ)の両方のファイルを同じフォルダに置く必要がある。

「勘定科目選択」画面でチェックされている科目しか表示されないのはeTaxソフトの仕様。  
プレゼンテーションXMLを定義することで表示可能ではあるが、インスタンスに数値は入っており税務署の関心のある科目のみ表示していると考えられるため、追加の対処は不要であろう。  
eTaxの表示順序仕様はブラックボックスであり、それを理解したうえで項目順を指定することには無理がある。

通達と反する点があるのであれば、まずeTaxソフトのデフォルト挙動を修正すべきと考える。  
特殊な技術操作をしなければ目的を達しない通達があるなら、違法の疑いがある。

### 売掛金の勘定科目内訳明細

luca-dealの請求をもとに勘定科目内訳明細インポート用CSVを生成する。luca-dealのデータディレクトリで`luca-jp urikake`を実行する。

```bash
# 期末時点の売掛残高CSVを出力
$ luca-jp urikake <yyyy> <mm>
```

e-taxソフトの「財務諸表等の組み込み」からインポートする。  
なお`luca-jp`は、e-tax仕様のShitJISでCSV出力するが変換できない文字がある場合、異常終了する。  
この場合、`--utf8`オプションで出力し、編集のうえ別途変換する必要がある。

正確な残高を出力するには、`luca-deal invoices settle`コマンドを利用して入金を追跡できていることが前提。
