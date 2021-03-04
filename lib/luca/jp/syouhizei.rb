# frozen_string_literal: true

require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca_support/config'

module Luca
  module Jp
    class Syouhizei
      def initialize(from_year, from_month, to_year = from_year, to_month = from_month)
        @dict = LucaRecord::Dict.load('base.tsv')
        @state = LucaBook::State.range(from_year, from_month, to_year, to_month)
      end

      # TODO: 軽減税率売上の識別
      #
      def kani
        税率 = 10 # percent
        @state.pl
        sales = @state.pl_data.dig('A0')
        tax_amount = sales * 10 / 100
        みなし仕入額 = tax_amount * みなし仕入率(LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')) / 100
        税額 = LucaSupport::Code.readable(tax_amount - みなし仕入額)
      end

      private

      def みなし仕入率(事業区分)
        {
          1 => 90,
          2 => 80,
          3 => 70,
          4 => 60,
          5 => 50,
          6 => 40
        }[事業区分]
      end
    end
  end
end
