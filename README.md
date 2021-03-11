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

## Format

各種書類に出力するデータは会計により出力可能な範囲に限り、eTaxソフトなどで追加編集のうえ提出。また、特定の法人を前提としている

法人税
---------

* 別表1
* 別表1次葉
* 別表2
* 別表4
* 別表5-1
* 別表5-2
* 別表15
* 適用額明細書
* 事業概況報告書
* 預貯金の勘定科目内訳書
* 仮受金の勘定科目内訳書
* 役員報酬の勘定科目内訳書


消費税
---------

* 簡易課税申告書
* 付表4-3
* 付表5-3


地方税
---------

* 6号様式
* 均等割に関する明細書
