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

`luca-jp`コマンドに期間指定して税額計算、仕訳データ、申告データを生成。

あらかじめ、`--export`オプションで確定税額の仕訳を生成し、LucaBookにインポートしておく必要がある。  
消費税課税事業者は、`luca-jp syouhizei --export`を最初に実行する。

仕訳を一式インポートしたうえで、`luca-jp`コマンドでeTax用のxtxまたはeLtax用のXMLを出力。

```bash
# LucaBookのディレクトリトップで実行する
$ cd </path/to/project-dir>

# exportオプションはLucaBookインポート用の仕訳を出力
$ luca-jp [houjinzei|syouhizei|chihouzei] --export [<yyyy> <mm> <yyyy> <mm>] > <export.json>
$ cat <export.json> | luca-book journals import --json

$ luca-jp [houjinzei|syouhizei] [<yyyy> <mm> <yyyy> <mm>] > <tax.xtx>
# 地方税はchihouzei-<jimusho_code>.xmlを出力
$ luca-jp chihouzei [<yyyy> <mm> <yyyy> <mm>]
```

* xtxファイルはeTaxソフトの「作成」->「申告・申請等」->「組み込み」からインポート可能


LucaBookの日本用標準勘定科目を利用した仕訳データを前提としている。税務署は内訳データを求めているため、税金納付などは種目を細かく分類して記帳しなくてはならない。

* 中間納付の計算上、最終月は計算から除外する。決算仕訳により相殺される影響を受けない


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
