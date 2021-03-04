# frozen_string_literal: true

require 'luca_book'
require 'luca_record/dict'

module Luca
  module Jp
    class Kessan
      def initialize
        @dict = LucaRecord::Dict.load('base.tsv')
      end

      def beppyo4
      end
    end
  end
end
