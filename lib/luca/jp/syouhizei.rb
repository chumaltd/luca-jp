# frozen_string_literal: true

require 'luca_book'
require 'luca_record/dict'

module Luca
  module Jp
    class Syouhizei
      def initialize(from_year, from_month, to_year = from_year, to_month = from_month)
        @dict = LucaRecord::Dict.load('base.tsv')
        @state = LucaBook::State(from_year, from_month, to_year, to_month)
      end

      # TODO: 軽減税率売上の識別
      #
      def kani
        sales = @state.pl.dig('A0')
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
