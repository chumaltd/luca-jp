# frozen_string_literal: true

require_relative 'test_helper'
require 'luca_record'
require 'luca_support/const'
require 'luca/jp'
require 'pathname'

class Luca::Jp::RefundBeppyo52Test < Minitest::Test
  def setup
    create_project(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf([Pathname(LucaSupport::CONST.pjdir) / 'data' ])
  end

  def test_beppyo4_temporary_taxes_receivable
    interim_tax_payment
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 0, tax[:kokuzei][:zeigaku]

    assert_equal 0, jptax.instance_variable_get(:@損金経理をした法人税及び地方法人税)
    assert_equal [1009, 1011].sum, jptax.instance_variable_get(:@損金経理をした道府県民税及び市町村民税)
    assert_equal jptax.send(:均等割).sum - [1009, 1011].sum, jptax.instance_variable_get(:@損金経理をした納税充当金)

    assert_equal 0 - jptax.send(:均等割).sum, jptax.instance_variable_get(:@当期純損益)

    assert_equal jptax.send(:均等割).sum, jptax.instance_variable_get(:@損金不算入額)
    assert_equal jptax.instance_variable_get(:@損金不算入額留保), jptax.instance_variable_get(:@損金不算入額)
    assert_equal 0, jptax.instance_variable_get(:@損金不算入額社外流出)

    assert_equal [1003, 1004, 1005, 1006, 1007].sum, jptax.instance_variable_get(:@益金不算入額)
    assert_equal [1003, 1004, 1005, 1006, 1007].sum, jptax.instance_variable_get(:@益金不算入額留保)
    assert_equal 0, jptax.instance_variable_get(:@益金不算入額社外流出)

    assert_equal 0 - [1003, 1004, 1005, 1006, 1007].sum, jptax.instance_variable_get(:@別表四調整所得)
    assert_equal 0 - [1003, 1004, 1005, 1006, 1007].sum, jptax.instance_variable_get(:@別表四調整所得留保)
    assert_equal jptax.instance_variable_get(:@当期純損益), jptax.instance_variable_get(:@別表四調整所得社外流出)
  end

  def test_beppyo52_temporary_taxes_receivable
    interim_tax_payment
    prep = %Q([
      {
      "date": "2020-12-31",
      "debit": [
      {
      "label": "未収法人税",
      "amount": 2003
      },
      {
      "label": "未収地方事業税",
      "amount": 5025
      },
      {
      "label": "未収都道府県住民税",
      "amount": 2017
      },
      {
      "label": "未収市町村住民税",
      "amount": 2021
      }
      ],
      "credit": [
      {
      "label": "仮払法人税",
      "amount": 1001
      },
      {
      "label": "仮払法人税(地方)",
      "amount": 1002
      },
      {
      "label": "仮払地方税特別法人事業税",
      "amount": 1003
      },
      {
      "label": "仮払地方税所得割",
      "amount": 1004
      },
      {
      "label": "仮払地方税収入割",
      "amount": 1005
      },
      {
      "label": "仮払地方税資本割",
      "amount": 1006
      },
      {
      "label": "仮払地方税付加価値割",
      "amount": 1007
      },
      {
      "label": "仮払地方税法人税割",
      "amount": 1008
      },
      {
      "label": "仮払地方税均等割",
      "amount": 1009
      },
      {
      "label": "仮払市民税法人税割",
      "amount": 1010
      },
      {
      "label": "仮払市民税均等割",
      "amount": 1011
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 0, jptax.send(:期首未納法人税)
    assert_equal 1001, jptax.instance_variable_get(:@法人税中間納付)
    assert_equal 1002, jptax.instance_variable_get(:@地方法人税中間納付)
    assert_equal 2003, jptax.send(:法人税仮払納付額)
    assert_equal 0, jptax.send(:法人税損金納付額)
    assert_equal 2003, jptax.instance_variable_get(:@翌期還付法人税)
    assert_equal 0, jptax.send(:期末未納法人税)

    assert_equal 0, jptax.send(:期首未納都道府県民税)
    assert_equal 2017, jptax.instance_variable_get(:@都道府県民税中間納付)
    assert_equal 2017, jptax.send(:都道府県民税仮払納付)
    assert_equal 0, jptax.send(:都道府県民税損金納付)
    assert_equal 0, jptax.send(:確定都道府県住民税)
    assert_equal 2017, jptax.instance_variable_get(:@翌期還付都道府県住民税)
    assert_equal 0, jptax.send(:期首未納市民税)
    assert_equal 2021, jptax.instance_variable_get(:@市民税中間納付)
    assert_equal 2021, jptax.send(:市民税仮払納付)
    assert_equal 0, jptax.send(:市民税損金納付)
    assert_equal 0, jptax.send(:確定市民税)
    assert_equal 2021, jptax.instance_variable_get(:@翌期還付市民税)

    assert_equal 0, jptax.instance_variable_get(:@事業税期首残高)
    assert_equal 0, jptax.send(:期首未納事業税)
    assert_equal 5025, jptax.instance_variable_get(:@事業税中間納付)
    assert_equal 0, jptax.send(:事業税損金納付)
    assert_equal 5025, jptax.instance_variable_get(:@翌期還付事業税)

    assert_equal 0, jptax.send(:期首納税充当金)
    assert_equal 0, jptax.send(:納税充当金期中減)
    assert_equal 0, jptax.send(:当期納税充当金)
  end

  # TODO: 期末に経過勘定が残っている場合の還付認識。適切な経理ではないため優先度低
  def test_beppyo52_temporary_taxes_refund
    interim_tax_payment
    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 1001, jptax.instance_variable_get(:@法人税中間納付)
    assert_equal 2003, jptax.send(:法人税仮払納付額)
    assert_equal 0, jptax.send(:法人税損金納付額)

    assert_equal 2017, jptax.instance_variable_get(:@都道府県民税中間納付)
    #assert_equal 2017, jptax.send(:都道府県民税仮払納付)
    #assert_equal 0, jptax.send(:都道府県民税損金納付)
    assert_equal 2021, jptax.instance_variable_get(:@市民税中間納付)
    #assert_equal 2021, jptax.send(:市民税仮払納付)
    #assert_equal 0, jptax.send(:市民税損金納付)

    assert_equal 5025, jptax.instance_variable_get(:@事業税中間納付)
    assert_equal 0, jptax.send(:事業税損金納付)
  end

  def interim_tax_payment
    prep = %Q([
      {
      "date": "2020-03-01",
      "debit": [
      {
      "label": "仮払法人税",
      "amount": 1001
      },
      {
      "label": "仮払法人税(地方)",
      "amount": 1002
      },
      {
      "label": "仮払地方税特別法人事業税",
      "amount": 1003
      },
      {
      "label": "仮払地方税所得割",
      "amount": 1004
      },
      {
      "label": "仮払地方税収入割",
      "amount": 1005
      },
      {
      "label": "仮払地方税資本割",
      "amount": 1006
      },
      {
      "label": "仮払地方税付加価値割",
      "amount": 1007
      },
      {
      "label": "仮払地方税法人税割",
      "amount": 1008
      },
      {
      "label": "仮払地方税均等割",
      "amount": 1009
      },
      {
      "label": "仮払市民税法人税割",
      "amount": 1010
      },
      {
      "label": "仮払市民税均等割",
      "amount": 1011
      }
      ],
      "credit": [
      {
      "label": "現金",
      "amount": 11066
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
  end
end
