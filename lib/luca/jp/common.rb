# frozen_string_literal: true

require 'luca_support'

module Luca
  module Jp
    module Common
      module_function

      # 法人税、地方税の当期確定税額の計算
      #
      def 税額計算
        所得 = 所得金額
        { houjin: {}, kenmin: {}, shimin: {} }.tap do |tax|
          法人税額 = 中小企業の軽減税額(所得) + 一般区分の税額(所得)
          tax[:houjin][:kokuzei] = (法人税額 / 100).floor * 100
          地方法人税課税標準 = (法人税額 / 1000).floor * 1000
          地方法人税 = 地方法人税額(地方法人税課税標準)
          tax[:houjin][:chihou] = (地方法人税 / 100).floor * 100

          tax[:kenmin][:houjinzei], tax[:shimin][:houjinzei] = 法人税割(法人税額)
          tax[:kenmin][:kintou], tax[:shimin][:kintou] = 均等割
          tax[:kenmin][:shotoku] = 所得割400万以下(所得) + 所得割800万以下(所得) + 所得割800万超(所得)
          tax[:kenmin][:tokubetsu] = 地方法人特別税(tax[:kenmin][:shotoku])
        end
      end

      # -----------------------------------------------------
      # :section: 法人税額の計算
      # -----------------------------------------------------

      def 中小企業の軽減税率対象所得(所得 = nil)
        所得 ||= 所得金額
        if 所得 >= 8_000_000
          8_000_000
        elsif 所得 < 0
          0
        else
          (所得 / 1000).floor * 1000
        end
      end

      def 中小企業の軽減税額(所得 = nil)
        中小企業の軽減税率対象所得(所得) * 15 / 100
      end

      def 中小企業の軽減税率対象を超える所得(所得 = nil)
        所得 ||= 所得金額
        if 所得 <= 8_000_000
          0
        else
          ((所得 - 8_000_000) / 1000).floor * 1000
        end
      end

      def 一般区分の税額(所得 = nil)
        (中小企業の軽減税率対象を超える所得(所得) * 23.2 / 100).to_i
      end

      def 地方法人税額(地方法人税課税標準)
        (地方法人税課税標準 * 10.3 / 100).to_i
      end

      # 税引前当期利益をもとに計算
      # 消費税を租税公課に計上している場合、控除済みの金額
      # 未払/未収事業税は精算時に認識
      #
      def 所得金額
        _, 納付事業税 = 未納事業税期中増減
        LucaSupport::Code.readable(@pl_data.dig('GA') - 納付事業税 + 還付事業税)
      end

      # -----------------------------------------------------
      # :section: 地方税額の計算
      # -----------------------------------------------------

      def 均等割
        if LucaSupport::CONFIG.dig('jp', 'eltax', 'office_23ku')
          [70_000, 0]
        else
          [20_000, 50_000]
        end
      end

      def 法人税割(法人税 = nil)
        課税標準 = if 法人税
                     (法人税 / 1000).floor * 1000
                   else
                     @法人税割課税標準
                   end
        if LucaSupport::CONFIG.dig('jp', 'eltax', 'office_23ku')
          [(課税標準 * 7 / 100).floor, 0]
        else
          [(課税標準 * 1 / 100).floor, (課税標準 * 6 / 100).floor]
        end
      end

      def 所得400万以下(所得 = nil)
        所得 ||= 所得金額
        if 所得 >= 4_000_000
          4_000_000
        else
          (所得 / 1000).floor * 1000
        end
      end

      def 所得割400万以下(所得 = nil)
        ((所得400万以下(所得) * 3.5 / 100) / 100).floor * 100
      end

      def 所得800万以下(所得 = nil)
        所得 ||= 所得金額
        if 所得 <= 4_000_000
          0
        elsif 所得 >= 8_000_000
          4_000_000
        else
          ((所得 - 4_000_000) / 1000).floor * 1000
        end
      end

      def 所得割800万以下(所得 = nil)
        ((所得800万以下(所得) * 5.3 / 100) / 100).floor * 100
      end

      def 所得800万超(所得 = nil)
        所得 ||= 所得金額
        if 所得 <= 8_000_000
          0
        else
          ((所得 - 8_000_000) / 1000).floor * 1000
        end
      end

      def 所得割800万超(所得 = nil)
        ((所得800万超(所得) * 7.0 / 100) / 100).floor * 100
      end

      def 地方法人特別税(事業税)
        ((事業税 * 37 / 100) / 100).floor * 100
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
