# frozen_string_literal: true

require 'luca_support'

module Luca
  module Jp
    module Common
      module_function

      # 税引前当期利益をもとに計算
      # 消費税を租税公課に計上している場合、控除済みの金額
      # 未払/未収事業税は精算時に認識
      #
      def 所得金額
        _, 納付事業税 = 未納事業税期中増減
        LucaSupport::Code.readable(@pl_data.dig('GA') - 納付事業税 + 還付事業税)
      end

      def 消費税課税売上高(税率 = 10)
        LucaSupport::Code.readable(@pl_data.dig('A0') * 100 / (100 + 税率).floor || 0)
      end

      def 納付税額(税額, 中間納付額)
        if 税額 > 中間納付額
          税額 - 中間納付額
        else
          0
        end
      end

      def 中間還付税額(税額, 中間納付額)
        if 税額 < 中間納付額
          中間納付額 - 税額
        else
          0
        end
      end

      def 還付事業税
        LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '1504')[:credit]
      end

      def 未納事業税期中増減
        r = LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '5152')
        [LucaSupport::Code.readable(r[:credit] || 0), LucaSupport::Code.readable(r[:debit] || 0)]
      end
    end
  end
end
