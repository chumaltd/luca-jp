# frozen_string_literal: true

require_relative 'test_helper'
require 'luca_book/dict'
require 'luca_record'
require 'luca_support/const'
require 'luca/jp'
require 'pathname'

class Luca::Jp::PaymentNextFYTest < Minitest::Test
  def setup
    create_project(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf([Pathname(LucaSupport::CONST.pjdir) / 'data' ])
  end

  def test_beppyo4_taxes_payment
    prev_fy_tax
    current_fy_payment
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 0, tax[:kokuzei][:zeigaku]

    assert_equal 0 - jptax.send(:均等割).sum, jptax.instance_variable_get(:@当期純損益)
    assert_equal jptax.send(:均等割).sum, jptax.instance_variable_get(:@損金経理をした納税充当金)

    assert_equal 3000, jptax.instance_variable_get(:@益金不算入額)
    assert_equal 3000, jptax.instance_variable_get(:@益金不算入額留保)
    assert_equal 0, jptax.instance_variable_get(:@益金不算入額社外流出)

    assert_equal [
                   jptax.send(:均等割).sum,
                 ].compact.sum, jptax.instance_variable_get(:@損金不算入額)
    assert_equal jptax.instance_variable_get(:@損金不算入額留保), jptax.instance_variable_get(:@損金不算入額)
    assert_equal 0, jptax.instance_variable_get(:@損金不算入額社外流出)

    assert_equal (-3000), jptax.instance_variable_get(:@別表四調整所得)
    assert_equal (-3000), jptax.send(:別表四調整所得合計留保)
    assert_equal jptax.instance_variable_get(:@当期純損益), jptax.send(:別表四調整所得合計社外流出)
  end

  def test_beppyo51_taxes_payment
    prev_fy_tax
    current_fy_payment
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 0, jptax.instance_variable_get(:@翌期還付法人税)
    assert_equal 0, jptax.instance_variable_get(:@当期還付事業税)
    assert_equal 0, jptax.instance_variable_get(:@翌期還付事業税)
    assert_equal 0, jptax.instance_variable_get(:@当期還付法人税)
    assert_equal 0, jptax.instance_variable_get(:@当期還付都道府県住民税)
    assert_equal 0, jptax.instance_variable_get(:@当期還付市民税)

    assert_equal 1000000 - 6006, jptax.send(:期首繰越損益)
    assert_equal  1000000 - 6006 - jptax.send(:均等割).sum, jptax.send(:期末繰越損益)

    assert_equal 0, jptax.instance_variable_get(:@期首資本金)
    assert_equal 0, jptax.instance_variable_get(:@資本金期中減)
    assert_equal 100000, jptax.instance_variable_get(:@資本金期中増)
    assert_equal 100000, jptax.send(:期末資本金)

    assert_equal 0, jptax.send(:別表五一期首資本)
    assert_equal 0, jptax.instance_variable_get(:@資本金等の額期中減)
    assert_equal 100000, jptax.instance_variable_get(:@資本金等の額期中増)
    assert_equal 100000, jptax.send(:資本金等の額)

    assert_equal [
                   1000000 - 6006,
                   3000,
                 ].compact.sum,
                 jptax.send(:別表五一期首差引金額)
    assert_equal [
                   1000000 - 6006,
                   3000,
                 ].compact.sum,
                 jptax.send(:別表五一期中減差引金額)
    assert_equal [
                   1000000 - 6006,
                   jptax.instance_variable_get(:@当期純損益),
                 ].sum,
                 jptax.send(:別表五一期中増差引金額)
    assert_equal [
                   1000000 - 6006,
                   jptax.instance_variable_get(:@当期純損益),
                 ].sum,
                 jptax.send(:別表五一期末差引金額)
    assert_equal jptax.send(:別表五一期末差引金額),
                 [
                   jptax.send(:別表五一期首差引金額),
                   jptax.send(:別表五一期中減差引金額) * -1,
                   jptax.send(:別表五一期中増差引金額)
                 ].sum
  end

  def test_beppyo52_taxes_payment
    prev_fy_tax
    current_fy_payment
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 1001, jptax.send(:期首未納法人税)
    assert_equal 0, jptax.instance_variable_get(:@法人税中間納付)
    assert_equal 0, jptax.instance_variable_get(:@地方法人税中間納付)
    assert_equal 0, jptax.send(:法人税仮払納付額)
    assert_equal 0, jptax.send(:法人税損金納付額)
    assert_equal 0, jptax.instance_variable_get(:@翌期還付法人税)
    assert_equal 0, jptax.send(:期末未納法人税)

    assert_equal 1002, jptax.send(:期首未納都道府県民税)
    assert_equal 0, jptax.instance_variable_get(:@都道府県民税中間納付)
    assert_equal 0, jptax.send(:都道府県民税仮払納付)
    assert_equal 0, jptax.send(:都道府県民税損金納付)
    assert_equal jptax.send(:均等割)[0], jptax.send(:確定都道府県住民税)
    assert_equal 0, jptax.instance_variable_get(:@翌期還付都道府県住民税)
    assert_equal 1003, jptax.send(:期首未納市民税)
    assert_equal 0, jptax.instance_variable_get(:@市民税中間納付)
    assert_equal 0, jptax.send(:市民税仮払納付)
    assert_equal 0, jptax.send(:市民税損金納付)
    assert_equal jptax.send(:均等割)[1], jptax.send(:確定市民税)
    assert_equal 0, jptax.instance_variable_get(:@翌期還付市民税)

    assert_equal 3000, jptax.instance_variable_get(:@事業税期首残高)
    assert_equal 3000, jptax.send(:期首未納事業税)
    assert_equal 0, jptax.instance_variable_get(:@事業税中間納付)
    assert_equal 0, jptax.send(:事業税損金納付)
    assert_equal 0, jptax.instance_variable_get(:@翌期還付事業税)

    assert_equal [1001, 1002, 1003, 3000].sum, jptax.send(:期首納税充当金)
    assert_equal [1001, 1002, 1003, 3000].sum, jptax.send(:納税充当金期中減)
    assert_equal jptax.send(:均等割).sum, jptax.send(:当期納税充当金)
    assert_equal jptax.send(:均等割).sum, jptax.send(:期末納税充当金)
  end

  def prev_fy_tax
    prep = %Q([
      {
      "date": "2019-01-01",
      "debit": [
      {
      "label": "現金",
      "amount": 1000000
      }
      ],
      "credit": [
      {
      "label": "売上高",
      "amount": 1000000
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
    prep2 = %Q([
      {
      "date": "2019-12-31",
      "debit": [
      {
      "label": "法人税、住民税及び事業税",
      "amount": 6006
      }
      ],
      "credit": [
      {
      "label": "未払法人税",
      "amount": 1001
      },
      {
      "label": "未払都道府県住民税",
      "amount": 1002
      },
      {
      "label": "未払市町村住民税",
      "amount": 1003
      },
      {
      "label": "未払地方事業税",
      "amount": 3000
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep2)
    LucaBook::Dict.generate_balance(2019, 12)
  end

  def current_fy_payment
    prep = %Q([
      {
      "date": "2020-03-01",
      "debit": [
      {
      "label": "未払法人税",
      "amount": 1001
      },
      {
      "label": "未払都道府県住民税",
      "amount": 1002
      },
      {
      "label": "未払市町村住民税",
      "amount": 1003
      },
      {
      "label": "未払地方事業税",
      "amount": 3000
      }
      ],
      "credit": [
      {
      "label": "現金",
      "amount": 6006
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
  end
end
