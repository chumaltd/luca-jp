# frozen_string_literal: true

require_relative 'test_helper'
require 'luca_book/dict'
require 'luca_record'
require 'luca_support/const'
require 'luca/jp'
require 'pathname'

class Luca::Jp::AccumulatedLossTest < Minitest::Test
  def setup
    create_project(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf([Pathname(LucaSupport::CONST.pjdir) / 'data' ])
  end

  def test_loss_available_after_1y
    initial_fy_loss
    current_fy_sales(2021)
    tax = apply_houjinzei(2021, 1, 2021, 12)
    apply_chihouzei(2021, 1, 2021, 12)

    jptax = Luca::Jp::Aoiro.range(2021, 1, 2021, 12)
    jptax.kani()

    assert_equal 0, tax[:kokuzei][:zeigaku]
    assert_equal 800000, jptax.instance_variable_get(:@別表四調整所得)
    assert_equal jptax.instance_variable_get(:@別表四調整所得), jptax.instance_variable_get(:@繰越損失管理).send(:deduction)
    assert_equal 0, jptax.instance_variable_get(:@繰越損失管理).send(:profit)

    assert_equal 1000000, jptax.send(:期首繰越損失)
    assert_equal 0, jptax.send(:当期繰越損失)
    assert_equal 800000, jptax.send(:当期控除計)
    assert_equal 1000000 - 800000, jptax.send(:翌期繰越損失)

    records = jptax.instance_variable_get(:@繰越損失管理).send(:records)
    assert_equal Date.new(2020, 1, 1), records[0]['start_date']
    assert_equal Date.new(2021, 12, 31), records[0]['decrease'][0]['date']
    assert_equal 800000, records[0]['decrease'][0]['val']
    assert_equal 1000000 - 800000, records[0]['amount']

    LucaBook::Dict.generate_balance(2021, 12)

    # NOTE: 残額の控除
    current_fy_sales(2022)
    tax2 = apply_houjinzei(2022, 1, 2022, 12)
    apply_chihouzei(2022, 1, 2022, 12)

    jptax2 = Luca::Jp::Aoiro.range(2022, 1, 2022, 12)
    jptax2.kani()

    assert tax2[:kokuzei][:zeigaku] > 0
    assert tax2[:kokuzei][:zeigaku] < jptax2.instance_variable_get(:@別表四調整所得) * 0.5
    assert_equal 800000, jptax2.instance_variable_get(:@別表四調整所得)
    assert_equal 1000000 - 800000, jptax2.instance_variable_get(:@繰越損失管理).send(:deduction)
    assert_equal 800000 - (1000000 - 800000), jptax2.instance_variable_get(:@繰越損失管理).send(:profit)

    assert_equal 1000000 - 800000, jptax2.send(:期首繰越損失)
    assert_equal 0, jptax2.send(:当期繰越損失)
    assert_equal 1000000 - 800000, jptax2.send(:当期控除計)
    assert_equal 0, jptax2.send(:翌期繰越損失)

    records2 = jptax2.instance_variable_get(:@繰越損失管理).send(:records)
    assert_equal Date.new(2020, 1, 1), records2[0]['start_date']
    assert_equal Date.new(2021, 12, 31), records2[0]['decrease'][0]['date']
    assert_equal 800000, records2[0]['decrease'][0]['val']
    assert_equal Date.new(2022, 12, 31), records2[0]['decrease'][1]['date']
    assert_equal 1000000 - 800000, records2[0]['decrease'][1]['val']
    assert_equal 0, records2[0]['amount']
  end

  def test_loss_expires_after_10y
    initial_fy_loss
    year = 2020
    10.times do
      year += 1
      apply_houjinzei(year, 1, year, 12)
      apply_chihouzei(year, 1, year, 12)
      LucaBook::Dict.generate_balance(year, 12)
    end

    # puts File.read(Pathname(LucaSupport::CONST.pjdir) / 'data' / 'balance' / 'sonshitsu.yml')
    current_fy_sales(2031)
    tax = apply_houjinzei(2031, 1, 2031, 12)
    apply_chihouzei(2031, 1, 2031, 12)

    jptax = Luca::Jp::Aoiro.range(2031, 1, 2031, 12)
    jptax.kani()

    assert tax[:kokuzei][:zeigaku] > 0
    assert tax[:kokuzei][:zeigaku] < jptax.instance_variable_get(:@別表四調整所得) * 0.5
    assert_equal 800000, jptax.instance_variable_get(:@別表四調整所得)
    assert_equal 0, jptax.instance_variable_get(:@繰越損失管理).send(:deduction)
    assert_equal 800000, jptax.instance_variable_get(:@繰越損失管理).send(:profit)

    assert_equal 0, jptax.send(:期首繰越損失)
    assert_equal 0, jptax.send(:当期繰越損失)
    assert_equal 0, jptax.send(:当期控除計)
    assert_equal 0, jptax.send(:翌期繰越損失)
  end

  def test_older_loss_wins_over_newer
    initial_fy_loss(2020, 150000)
    initial_fy_loss(2021, 1000000)
    current_fy_sales(2022)
    tax = apply_houjinzei(2022, 1, 2022, 12)
    apply_chihouzei(2022, 1, 2022, 12)

    jptax = Luca::Jp::Aoiro.range(2022, 1, 2022, 12)
    jptax.kani()

    assert_equal 0, tax[:kokuzei][:zeigaku]
    assert_equal 800000, jptax.instance_variable_get(:@別表四調整所得)
    assert_equal jptax.instance_variable_get(:@別表四調整所得), jptax.instance_variable_get(:@繰越損失管理).send(:deduction)
    assert_equal 0, jptax.instance_variable_get(:@繰越損失管理).send(:profit)

    assert_equal 1150000, jptax.send(:期首繰越損失)
    assert_equal 0, jptax.send(:当期繰越損失)
    assert_equal 800000, jptax.send(:当期控除計)
    assert_equal 1150000 - 800000, jptax.send(:翌期繰越損失)

    records = jptax.instance_variable_get(:@繰越損失管理).send(:records)
    assert_equal 0, records[0]['amount']
    assert_equal Date.new(2020, 1, 1), records[0]['start_date']
    assert_equal 1000000 - 800000 + 150000, records[1]['amount']
    assert_equal Date.new(2021, 1, 1), records[1]['start_date']
  end

  def initial_fy_loss(year = 2020, amount = 1000000)
    prep = %Q([
      {
      "date": "#{year}-08-01",
      "debit": [
      {
      "label": "支払手数料",
      "amount": #{amount}
      }
      ],
      "credit": [
      {
      "label": "現金",
      "amount": #{amount}
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
    apply_houjinzei(year, 1, year, 12)
    apply_chihouzei(year, 1, year, 12)
    LucaBook::Dict.generate_balance(year, 12)
  end

  def current_fy_sales(year)
    prep = %Q([
      {
      "date": "#{year}-03-01",
      "debit": [
      {
      "label": "現金",
      "amount": 800000
      }
      ],
      "credit": [
      {
      "label": "売上高",
      "amount": 800000
      }
      ]
      }
      ])
    LucaBook::Import.import_json(prep)
  end
end
