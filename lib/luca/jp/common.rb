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
        法人税額 = 中小企業の軽減税額(所得) + 一般区分の税額(所得)
        地方法人税課税標準 = (法人税額 / 1000).floor * 1000
        地方法人税 = 地方法人税額(地方法人税課税標準)
        { houjin: {}, kenmin: {}, shimin: {} }.tap do |tax|
          tax[:houjin][:kokuzei] = (法人税額 / 100).floor * 100
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
        return 0 if 軽減税率不適用法人

        所得 ||= 所得金額
        return 0 if 所得 <= 0

        if 所得 >= 8_000_000
          8_000_000
        else
          (所得 / 1000).floor * 1000
        end
      end

      def 中小企業の軽減税額(所得 = nil)
          中小企業の軽減税率対象所得(所得) * 15 / 100
      end

      def 中小企業の軽減税率対象を超える所得(所得 = nil)
        所得 ||= 所得金額
        return 0 if 所得 <= 8_000_000

        ((所得 - 8_000_000) / 1000).floor * 1000
      end

      def 一般区分の税額(所得 = nil)
        所得 ||= 所得金額
        return 0 if 所得 <= 0

        if 軽減税率不適用法人
          return ((所得 / 1000).floor * 1000 * 23.2 / 100).to_i
        end

        (中小企業の軽減税率対象を超える所得(所得) * 23.2 / 100).to_i
      end

      def 地方法人税額(地方法人税課税標準)
        (地方法人税課税標準 * 10.3 / 100).to_i
      end

      # 繰越損失適用後の所得金額
      #
      def 所得金額
        @繰越損失管理 = Sonshitsu.load(@end_date).update(@別表四調整所得) if @繰越損失管理.nil?
        @繰越損失管理.profit
      end

      # 消費税を租税公課に計上している場合、控除済みの金額
      # 事業税は仮払経理の場合にも納付時損金／還付時益金
      #
      def 別表四所得調整(ext_config = nil)
        @税引前損益 = readable(@pl_data.dig('GA'))

        if ext_config
          @減価償却の償却超過額 = ext_config.dig('損金不算入', '減価償却')
          @役員給与の損金不算入額 = ext_config.dig('損金不算入', '役員給与')
          @交際費等の損金不算入額 = ext_config.dig('損金不算入', '交際費')
          # 損金不算入額は損金経理したもの、税額控除額は仮払経理したもの
          @所得税等の損金不算入額 = ext_config.dig('損金不算入', '所得税')
          @減価償却超過額の当期認容額 = ext_config.dig('益金不算入', '減価償却')
          @受取配当金の益金不算入額 = ext_config.dig('益金不算入', '受取配当金')
          @受贈益の益金不算入額 = ext_config.dig('益金不算入', '受贈益')
        end

        @当期還付事業税 = refund_tax('1504')
        @損金不算入額税額未確定 = [
          @減価償却の償却超過額,
          @役員給与の損金不算入額,
          @交際費等の損金不算入額,
          @所得税等の損金不算入額,
          @当期還付事業税
        ].compact.sum

        _, @納付事業税 = 未納事業税期中増減
        @事業税中間納付 = ['1854', '1855', '1856', '1857', '1858']
                            .map{ |k| prepaid_tax(k) }.compact.sum
        @益金不算入額税額未確定 = [
          @納付事業税,
          @事業税中間納付,
          @減価償却超過額の当期認容額,
          @受取配当金の益金不算入額,
          @受贈益の益金不算入額,
        ].compact.sum

        @別表四調整所得 = @税引前損益 + @損金不算入額税額未確定 - @益金不算入額税額未確定 + 寄付金の損金不算入額
        # 税引前損益に含まれない税額控除対象所得税の認識
        @所得税等の損金不算入額 = [
          @所得税等の損金不算入額,
          prepaid_tax('H115')
        ].compact.sum
      end

      def 寄付金の損金不算入額
        寄付金 = LucaSupport::Code.readable(@pl_data.dig('C1X')||0)
        指定寄付金 = LucaSupport::Code.readable(@pl_data.dig('C1X1')||0)

        [
          寄付金 - 指定寄付金 - 一般寄付金の損金算入限度額,
          0
        ].max
      end

      def 一般寄付金の損金算入限度額
        寄付金算定所得 = @税引前損益 + @損金不算入額税額未確定 - @益金不算入額税額未確定 + LucaSupport::Code.readable(@pl_data.dig('C1X')||0)
        期末資本準備金 = LucaSupport::Code.readable(@bs_data.dig('9131')||0)

        ([
          ([寄付金算定所得, 0].max * 2.5 / 100).floor,
          ([期末資本金, 期末資本準備金].compact.sum * 2.5 / 1000).floor
        ].compact.sum / 4).floor
      end

      # -----------------------------------------------------
      # :section: 繰越損失の計算
      # -----------------------------------------------------

      def 期首繰越損失
        翌期繰越損失 + @繰越損失管理.deduction
      end

      def 当期控除計
        @繰越損失管理.deduction
      end

      def 翌期繰越損失
        @繰越損失管理.records
          .filter { |record| record['start_date'] > @end_date.prev_year(10) && record['end_date'] < @start_date }
          .inject(0) { |sum, record| [sum, record['amount']].compact.sum }
      end

      def 当期繰越損失
        @繰越損失管理.records
          .filter { |record| record['start_date'] == @start_date }.dig(0, 'increase') || 0
      end


      # -----------------------------------------------------
      # :section: 地方税額の計算
      # -----------------------------------------------------

      def 均等割
        if @employee.nil?
          STDERR.puts "地方税の提出先設定に従業員人数がないため、1名とみなして計算"
          @employee ||= 1
        end
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
        return 課税標準 if ! Luca::Jp::Util.eltax_config('reports')

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
