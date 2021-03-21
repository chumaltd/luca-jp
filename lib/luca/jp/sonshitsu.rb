# frozen_string_literal: true

require 'date'
require 'pathname'
require 'yaml'
require 'luca_book'
require 'luca_support/config'

module Luca
  module Jp
    # 青色申告に基く繰越損失の計算
    #
    class Sonshitsu
      # 当期控除額
      attr_reader :deduction
      # 控除後所得
      attr_reader :profit
      # 各期繰越損失
      attr_reader :records

      def initialize(records, date)
        @records = records
        @report_date = date
        net_amount
        @deduction = 0
        @profit = 0
      end

      # sonshitsu format is as bellows:
      #
      #   - start_date: 2020-01-01
      #     end_date: 2020-12-31
      #     increase: 1000000
      #   - start_date: 2021-01-01
      #     end_date: 2021-12-31
      #     decrease: 800000
      #
      def self.load(this_year)
        records = if File.exist?(record_file)
                    YAML.load_file(record_file)
                      .filter { |record| record['start_date'] > this_year.prev_year(11) && record['end_date'] < this_year }
                      .sort { |a, b| a['start_date'] <=> b['start_date'] }
                 else
                   []
                 end
        new(records, this_year)
      end

      def save
        File.open(self.class.record_file, 'w') { |f| f.puts YAML.dump(@records)}
        self
      end

      def update(profit_or_loss)
        return self if profit_or_loss == 0

        if profit_or_loss < 0
          start_date, end_date = LucaBook::Util.current_fy(@report_date)
          @records << {
            'start_date' => start_date,
            'end_date' => end_date,
            'increase' => profit_or_loss.abs
          }
          @profit = profit_or_loss
          return self
        end

        @records.each do |record|
          next if profit_or_loss <= 0
          next if record['amount'] <= 0

          decrease_amount = [record['amount'], profit_or_loss].min
          record['decrease'] ||= []
          record['decrease'] << { 'date' => @report_date, 'val' => decrease_amount }
          record['amount'] -= decrease_amount
          profit_or_loss -= decrease_amount
          @deduction += decrease_amount
        end
        @profit = profit_or_loss
        self
      end

      def net_amount
        @records.each do |record|
          record['amount'] = record['increase'] - past_decreased(record['decrease'])
          record['decrease'] = record['decrease']&.reject { |decrease_record| decrease_record['date'] > @report_date.prev_year }
        end
      end

      def past_decreased(decrease_records)
        return 0 if decrease_records.nil?

        decrease_records.filter { |record| record['date'] <= @report_date.prev_year }
          .map { |record| record['val'] }.sum || 0
      end

      def self.record_file
        Pathname(LucaSupport::PJDIR) / 'data' / 'balance' / 'sonshitsu.yml'
      end
    end
  end
end
