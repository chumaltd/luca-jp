# frozen_string_literal: true

require_relative 'test_helper'
require 'luca_book/dict'
require 'luca_record'
require 'luca_support/const'
require 'luca/jp'
require 'pathname'

class Luca::Jp::DonationCostTest < Minitest::Test
  def setup
    create_project(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf([Pathname(LucaSupport::CONST.pjdir) / 'data' ])
  end

  def test_donation_as_cost
    current_fy_payment(50)
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 0, jptax.send(:寄付金の損金不算入額)
    assert_equal [-1002, -50].sum, jptax.send(:別表四調整所得合計)
    assert_equal [-1002, -50].sum, jptax.send(:別表四調整所得合計留保)
    assert_equal jptax.instance_variable_get(:@当期純損益), jptax.send(:別表四調整所得合計社外流出)
  end

  def test_donation_over_limit
    current_fy_payment(500000)
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert jptax.send(:寄付金の損金不算入額) > 0
    assert [-1002, -500000].sum < jptax.send(:別表四調整所得合計)
    assert_equal [-1002, -500000].sum, jptax.send(:別表四調整所得合計留保)
    assert jptax.instance_variable_get(:@当期純損益) < jptax.send(:別表四調整所得合計社外流出)
  end

  def test_donation_no_limit
    current_fy_payment(500000, true)
    tax = apply_houjinzei
    eltax, eltax_json = apply_chihouzei

    jptax = Luca::Jp::Aoiro.range(2020, 1, 2020, 12)
    jptax.kani()

    assert_equal 0, jptax.send(:寄付金の損金不算入額)
    assert_equal [-1002, -500000].sum, jptax.send(:別表四調整所得合計)
    assert_equal [-1002, -500000].sum, jptax.send(:別表四調整所得合計留保)
    assert_equal jptax.instance_variable_get(:@当期純損益), jptax.send(:別表四調整所得合計社外流出)
  end

  def current_fy_payment(amount, no_limit = false)
    label = no_limit ? '指定寄付金' : '寄付金'
    prep = %Q([
      {
      "date": "2020-03-01",
      "debit": [
      {
      "label": "#{label}",
        "amount": #{amount}
          },
          {
          "label": "支払報酬",
          "amount": 1002
          }
      ],
      "credit": [
      {
      "label": "現金",
      "amount": #{1002 + amount}
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
  end
end
