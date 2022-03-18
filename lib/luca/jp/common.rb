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
          tax[:kenmin][:kintou], tax[:shimin][:kintou] = 均等割 if @report_category
          tax[:kenmin][:shotoku] = 所得割400万以下(所得) + 所得割800万以下(所得) + 所得割800万超(所得)
          tax[:kenmin][:tokubetsu] = 特別法人事業税(tax[:kenmin][:shotoku])
        end
      end

      # -----------------------------------------------------
      # :section: 法人税額の計算
      # -----------------------------------------------------

      def 中小企業の軽減税率対象所得(所得 = nil)
        所得 ||= 所得金額
        return 0 if 所得 <= 0

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
        return 0 if 所得 <= 0

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

      # 繰越損失適用後の所得金額
      #
      def 所得金額
        @繰越損失管理 = Sonshitsu.load(@end_date).update(当期所得金額).save if @繰越損失管理.nil?
        @繰越損失管理.profit
      end

      # 税引前当期利益をもとに計算
      # 消費税を租税公課に計上している場合、控除済みの金額
      # 事業税は仮払経理の場合にも納付時損金／還付時益金
      #
      def 当期所得金額
        _, 納付事業税 = 未納事業税期中増減
        事業税中間納付 = prepaid_tax('1854') + prepaid_tax('1855') + prepaid_tax('1856') + prepaid_tax('1857') + prepaid_tax('1858')
        LucaSupport::Code.readable(@pl_data.dig('GA') - 納付事業税 - 事業税中間納付 + 還付事業税)
      end

      # -----------------------------------------------------
      # :section: 繰越損失の計算
      # -----------------------------------------------------

      def 期首繰越損失
        @繰越損失管理.records
          .filter { |record| record['start_date'] > @end_date.prev_year(10) && record['end_date'] < @start_date }
          .inject(0) { |sum, record| sum + (record['amount'] || 0) }
      end

      def 当期控除計
        @繰越損失管理.deduction
      end

      def 翌期繰越損失
        @繰越損失管理.records
          .filter { |record| record['start_date'] > @end_date.prev_year(10) && record['end_date'] < @start_date }
          .inject(0) { |sum, record| sum + (record['amount'] || 0) }
      end

      def 当期繰越損失
        @繰越損失管理.records
          .filter { |record| record['start_date'] == @start_date }.dig(0, 'increase') || 0
      end


      # -----------------------------------------------------
      # :section: 地方税額の計算
      # -----------------------------------------------------

      def 均等割
        tax = if 地方税資本金等の額 <= 10_000_000
                city = @employee > 50 ? 120_000 : 50_000
                [20_000, city]
              elsif 地方税資本金等の額 <= 100_000_000
                city = @employee > 50 ? 150_000 : 130_000
                [50_000, city]
              elsif 地方税資本金等の額 <= 1_000_000_000
                city = @employee > 50 ? 400_000 : 160_000
                [130_000, city]
              elsif 地方税資本金等の額 <= 5_000_000_000
                city = @employee > 50 ? 1_750_000 : 410_000
                [540_000, city]
              else
                city = @employee > 50 ? 3_000_000 : 410_000
                [800_000, city]
              end
        tokyo23? ? [tax.sum, 0] : tax
      end

      # 100円未満切り捨て
      def 法人税割(法人税 = nil)
        課税標準 = if 法人税
                     (法人税 / 1000).floor * 1000
                   else
                     法人税割課税標準
                   end
        県税率, 市税率 = 法人税割税率(課税標準)
        [
          (課税標準 * 県税率 / 100 / 100).floor * 100,
          (課税標準 * 市税率 / 100 / 100).floor * 100
        ]
      end

      def 法人税割税率(法人税 = nil)
        return [@houjinzeiwari_rate.to_f, @houjinzeiwari_rate.to_f] if @houjinzeiwari_rate

        課税標準 = if 法人税
                     (法人税 / 1000).floor * 1000
                   else
                     法人税割課税標準
                   end
        rate = if 期末資本金 > 100_000_000 || 課税標準 > 10_000_000
                 [2.0, 8.4]
               else
                 [1.0, 6.0]
               end
        tokyo23? ? [rate.sum, 0] : rate
      end

      # 100円未満切り捨て
      def 所得割400万以下(所得 = nil)
        ((所得400万以下(所得) * 所得割税率400万以下(所得) / 100) / 100).floor * 100
      end

      def 所得400万以下(所得 = nil)
        所得 ||= 所得金額
        return 0 if 所得 < 0

        total = if 所得 >= 4_000_000
                  4_000_000
                else
                  (所得 / 1000).floor * 1000
                end
        事業税の分割課税標準(total)
      end

      def 所得割税率400万以下(所得 = nil)
        return @shotyoku399.to_f if @shotoku399

        所得 ||= 所得金額
        if 期末資本金 > 100_000_000 || 所得 > 25_000_000
          軽減税率不適用法人 ? 7.48 : 3.75
        else
          軽減税率不適用法人 ? 7.0 : 3.5
        end
      end

      # 100円未満切り捨て
      def 所得割800万以下(所得 = 0)
        ((所得800万以下(所得) * 所得割税率800万以下(所得) / 100) / 100).floor * 100
      end

      def 所得800万以下(所得 = nil)
        所得 ||= 所得金額
        return 0 if 所得 < 0

        total = if 所得 <= 4_000_000
                  0
                elsif 所得 >= 8_000_000
                  4_000_000
                else
                  ((所得 - 4_000_000) / 1000).floor * 1000
                end
        事業税の分割課税標準(total)
      end

      def 所得割税率800万以下(所得 = nil)
        return @shotyoku401.to_f if @shotoku401

        所得 ||= 所得金額
        if 期末資本金 > 100_000_000 || 所得 > 25_000_000
          軽減税率不適用法人 ? 7.48 : 5.665
        else
          軽減税率不適用法人 ? 7.0 : 5.3
        end
      end

      # 100円未満切り捨て
      def 所得割800万超(所得 = 0)
        ((所得800万超(所得) * 所得割税率800万超(所得) / 100) / 100).floor * 100
      end

      def 所得800万超(所得 = nil)
        所得 ||= 所得金額
        return 0 if 所得 < 0

        total = if 所得 <= 8_000_000
          0
        else
          ((所得 - 8_000_000) / 1000).floor * 1000
        end
        事業税の分割課税標準(total)
      end

      def 所得割税率800万超(所得 = nil)
        return @shotyoku801.to_f if @shotoku801

        所得 ||= 所得金額
        if 期末資本金 > 100_000_000 || 所得 > 25_000_000
          7.48
        else
          7.0
        end
      end

      # 100円未満切り捨て
      def 特別法人事業税(事業税)
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
        refund_tax('1504')
      end

      def 未納事業税期中増減
        r = gross_amount('5152', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        [LucaSupport::Code.readable(r[1]), LucaSupport::Code.readable(r[0])]
      end


      # -----------------------------------------------------
      # :section: 消費税の計算
      # -----------------------------------------------------

      def 消費税中間納付額
        prepaid_tax('185B')
      end

      def 地方消費税中間納付額
        prepaid_tax('185C')
      end

      # -----------------------------------------------------
      # :section: 外形標準の計算
      # -----------------------------------------------------
      def 資本金等の額
        readable(['911', '913', '916'].map { |cd| @bs_data.dig(cd) }.compact.sum)
      end

      def 地方税資本金等の額
        [資本金等の額, readable(['911', '9131'].map { |cd| @bs_data.dig(cd) }.compact.sum)].max
      end

      def 軽減税率不適用法人
        期末資本金 > 10_000_000 && eltax_config('no_keigen')
      end

      def 期末資本金
        readable(@bs_data.dig('911'))
      end

      # -----------------------------------------------------
      # :section: 複数自治体間の分割計算
      # -----------------------------------------------------
      def 事業税の分割課税標準(課税標準)
        case Luca::Jp::Util.eltax_config('reports')
               .filter { |r| レポート種別.include?(r['type']) }.length
        when 0, 1
          課税標準
        else
          half = (課税標準 / 2 / 1000).floor * 1000
          [
            事業所数による分割課税標準(half),
            従業員数による分割課税標準(half)
          ].sum
        end
      end

      def 従業員数による分割課税標準(課税標準)
        分割基準の総数 = Luca::Jp::Util.eltax_config('reports')
                           .filter { |r| レポート種別.include?(r['type']) }
                           .map { |r| (r['employee'] || 1).to_i }.sum
        ((課税標準.to_f / 分割基準の総数).floor(分割基準の総数.to_s.length) * @employee / 1000)
          .floor * 1000
      end

      def 事業所数による分割課税標準(課税標準)
        分割基準の総数 = Luca::Jp::Util.eltax_config('reports')
                           .filter { |r| レポート種別.include?(r['type']) }
                           .map { |r| (r['office_count'] || 1).to_i }.sum
        ((課税標準.to_f / 分割基準の総数).floor(分割基準の総数.to_s.length) * @office_count / 1000)
          .floor * 1000
      end

      def レポート種別
        @report_category == 'city' ? ['city', '23ku'] : ['prefecture', '23ku']
      end
    end
  end
end
