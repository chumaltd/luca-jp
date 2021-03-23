# frozen_string_literal: true

require 'json'
require 'cgi/escape'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca_support/config'
require 'luca/jp'

module Luca
  module Jp
    class Aoiro < LucaBook::State
      include LucaSupport::View
      include LucaSupport::Code
      include Luca::Jp::Common
      include Luca::Jp::ItPart
      include Luca::Jp::Util

      @dirname = 'journals'
      @record_type = 'raw'

      def kani(export: false)
        set_pl(4)
        set_bs(4)
        @issue_date = Date.today
        @company = CGI.escapeHTML(config.dig('company', 'name'))
        @software = 'LucaJp'

        @税額 = 税額計算
        @確定法人税額 = @税額.dig(:houjin, :kokuzei)
        @法人税額 = 中小企業の軽減税額 + 一般区分の税額
        @地方法人税課税標準 = (@法人税額 / 1000).floor * 1000
        @地方法人税額 = 地方法人税額(@地方法人税課税標準)
        @確定地方法人税額 = @税額.dig(:houjin, :chihou)
        @法人税中間納付 = prepaid_tax('1851')
        @地方法人税中間納付 = prepaid_tax('1852')

        if export
          {
            kokuzei: {
              zeigaku: @確定法人税額,
              chukan: @法人税中間納付
            },
            chihou: {
              zeigaku: @確定地方法人税額,
              chukan: @地方法人税中間納付
            }
          }
        else
          @procedure_code = 'RHO0012'
          @procedure_name = '内国法人の確定申告(青色)'
          @version = '20.0.2'
          @都道府県民税中間納付 = prepaid_tax('1859') +  prepaid_tax('185A')
          @市民税中間納付 = prepaid_tax('185D') +  prepaid_tax('185E')
          @法人税期中増, @法人税期中減 = 未納法人税期中増減
          @都道府県民税期中増, @都道府県民税期中減 = 未納都道府県民税期中増減
          @市民税期中増, @市民税期中減 = 未納市民税期中増減
          @事業税期中増, @事業税期中減 = 未納事業税期中増減
          @納税充当金期中増, @納税充当金期中減 = 納税充当金期中増減
          @還付法人税 = refund_tax('1502')
          @還付都道府県住民税 = refund_tax('1503')
          @還付市民税 = refund_tax('1505')
          @概況売上 = gaikyo('A0')
          @form_sec = ['HOA112', 'HOA116', 'HOA201', 'HOA420', 'HOA511', 'HOA522', 別表七フォーム, 'HOE200', 適用額明細フォーム, 'HOI010', 'HOI100', 'HOI141', 'HOK010'].compact.map{ |c| form_rdf(c) }.join('')
          #@extra_form_sec = ['HOI040', 'HOI060', 'HOI090', 'HOI110']
          @it = it_part
          @form_data = [別表一, 別表一次葉, 別表二, 別表四簡易, 別表五一, 別表五二, 別表七, 別表十五, 適用額明細, 預貯金内訳, 仮受金内訳, 役員報酬内訳, 概況説明].compact.join("\n")
          render_erb(search_template('aoiro.xtx.erb'))
        end
      end

      def export_json
        dat = kani(export: true)
        [].tap do |res|
          item = {}
          item['date'] = @end_date
          item['debit'] = []
          item['credit'] = []
          if dat[:kokuzei][:chukan] > 0
            item['credit'] << { 'label' => '仮払法人税', 'amount' => dat[:kokuzei][:chukan] }
          end
          if dat[:kokuzei][:chukan] > dat[:kokuzei][:zeigaku]
            item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:kokuzei][:chukan] - dat[:kokuzei][:zeigaku] }
          else
            item['credit'] << { 'label' => '未払法人税', 'amount' => dat[:kokuzei][:zeigaku] - dat[:kokuzei][:chukan] }
          end
          item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:kokuzei][:zeigaku] } if dat[:kokuzei][:zeigaku] > 0
          if dat[:chihou][:chukan] > 0
            item['credit'] << { 'label' => '仮払法人税(地方)', 'amount' => dat[:chihou][:chukan] }
          end
          if dat[:chihou][:chukan] > dat[:chihou][:zeigaku]
            item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:chihou][:chukan] - dat[:chihou][:zeigaku] }
          else
            item['credit'] << { 'label' => '未払法人税', 'amount' => dat[:chihou][:zeigaku] - dat[:chihou][:chukan] }
          end
          item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:chihou][:zeigaku] } if dat[:chihou][:zeigaku] > 0
          item['x-editor'] = 'LucaJp'
          res << item
          puts JSON.dump(res)
        end
      end

      def 別表一
        render_erb(search_template('beppyo1.xml.erb'))
      end

      def 別表一次葉
        @消費税期中増, @消費税期中減 = 未納消費税期中増減
        render_erb(search_template('beppyo1-next.xml.erb'))
      end

      def 別表二
        render_erb(search_template('beppyo2.xml.erb'))
      end

      def 別表四簡易
        @当期純損益 = readable(@pl_data.dig('HA'))
        @法人税等 = readable(@pl_data.dig('H0'))
        _, @納付事業税 = 未納事業税期中増減
        @還付事業税 = readable(還付事業税 || 0)
        @別表四調整所得 = @当期純損益 + @法人税等 + @還付事業税 - @納付事業税

        render_erb(search_template('beppyo4.xml.erb'))
      end

      def 別表五一
        render_erb(search_template('beppyo51.xml.erb'))
      end

      def 別表五二
        @その他事業税 = 租税公課
        render_erb(search_template('beppyo52.xml.erb'))
      end

      def 別表七フォーム
        return nil if @繰越損失管理.records.length == 0

        'HOB710'
      end

      def 別表七
        return nil if @繰越損失管理.records.length == 0

        render_erb(search_template('beppyo7.xml.erb'))
      end

      def 別表十五
        @交際費 = readable(@pl_data.dig('C1B') || 0)
        @限度額 = @交際費 < 4_000_000 ? @交際費 : 4_000_000
        @不算入額 = @交際費 < 4_000_000 ? 0 : @交際費 - 4_000_000
        render_erb(search_template('beppyo15.xml.erb'))
      end

      def 預貯金内訳
        @預金 = @bs_data.each.with_object({}) do |(k, v), h|
          next unless /^110[0-9A-Z]/.match(k)
          next unless readable(v || 0) > 0

          h[@@dict.dig(k)[:label]] = readable(v)
        end
        render_erb(search_template('yokin-meisai.xml.erb'))
      end

      def 仮受金内訳
        @源泉給与 = readable(@bs_data.dig('5191') || 0)
        @源泉報酬 = readable(@bs_data.dig('5193') || 0)
        render_erb(search_template('kariuke-meisai.xml.erb'))
      end

      def 役員報酬内訳
        @役員報酬 = readable(@pl_data.dig('C11') || 0)
        @給料 = readable(@pl_data.dig('C12') || 0)
        render_erb(search_template('yakuin-meisai.xml.erb'))
      end

      def 適用額明細フォーム
        return nil if @確定法人税額 == 0

        'HOE990'
      end

      def 適用額明細
        return nil if @確定法人税額 == 0

        render_erb(search_template('tekiyougaku.xml.erb'))
      end

      def 概況説明
        @概況粗利益 = gaikyo('BA')
        @概況役員報酬 = gaikyo('C11')
        @概況給料 = gaikyo('C12')
        @概況交際費 = gaikyo('C1B')
        @概況減価償却 = gaikyo('C1P')
        @概況地代租税 = gaikyo('C1E') + gaikyo('C1I')
        @概況営業損益 = gaikyo('CA')
        @概況特別利益 = gaikyo('F0')
        @概況特別損失 = gaikyo('G0')
        @概況税引前損益 = gaikyo('GA')
        @概況資産計 = gaikyo('5')
        @概況現預金 = gaikyo('10')
        @概況受取手形 = gaikyo('120')
        @概況売掛金 = gaikyo('130')
        @概況棚卸資産 = gaikyo('160')
        @概況貸付金 = gaikyo('140') + gaikyo('333')
        @概況建物 = gaikyo('311')
        @概況機械 = gaikyo('313')
        @概況車船 = gaikyo('314') + gaikyo('318')
        @概況土地 = gaikyo('316')
        @概況負債計 = gaikyo('8ZZ')
        @概況支払手形 = gaikyo('510')
        @概況買掛金 = gaikyo('511')
        @概況個人借入金 = gaikyo('5121')
        @概況ほか借入金 =  gaikyo('512') - gaikyo('5121')
        @概況純資産 = gaikyo('9ZZ')
        @代表者報酬 = gaikyo('C11')
        @代表者借入 = gaikyo('5121')
        @概況仕入 = gaikyo('B11') + gaikyo('B12')
        @概況外注費 = gaikyo('C10')
        @概況人件費 = gaikyo('C11') + gaikyo('C12') + gaikyo('C13')
        render_erb(search_template('gaikyo.xml.erb'))
      end

      private

      def 期首未納事業税
        readable(@start_balance.dig('5152')) || 0
      end

      def 期末未納事業税
        readable(@bs_data.dig('5152')) || 0
      end

      def 当期事業税納付
        readable(@pl_data.dig('C1I2')) || 0
      end

      def 租税公課
        readable(LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: 'C1I')[:debit]['C1I']) || 0
      end

      def 別表四還付事業税
        return nil if @還付事業税 == 0

        "<ARC00220><ARC00230>仮払事業税消却(未収計上した還付事業税)</ARC00230>#{render_attr('ARC00240', @還付事業税)}#{render_attr('ARC00250', @還付事業税)}</ARC00220>\n"
      end

      def 期首繰越損益
        readable(@start_balance.dig('914')) || 0
      end

      def 期末繰越損益
        readable(@bs_data.dig('914')) || 0
      end

      def 期首納税充当金
        readable(@start_balance.dig('515')) || 0
      end

      def 期末納税充当金
        readable(@bs_data.dig('515')) || 0
      end

      def 納税充当金期中増減
        r = LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '515')
        [
          readable(r[:credit]['515'] || 0) + @法人税期中増 + @都道府県民税期中増 + @市民税期中増 + @事業税期中増,
          readable(r[:debit]['515'] || 0) + @法人税期中減 + @都道府県民税期中減 + @市民税期中減 + @事業税期中減
        ]
      end

      def 期首未納法人税
        readable(@start_balance.dig('5151')) || 0
      end

      def 期末未納法人税
        readable(@bs_data.dig('5151')) || 0
      end

      def 未納法人税期中増減
        r = LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '5151')
        [readable(r[:credit]['5151'] || 0), readable(r[:debit]['5151'] || 0)]
      end

      # 中間納付した金額のうち税額とならず、還付されるべき額
      #
      def 法人税仮払納付額
        [(@法人税中間納付 + @地方法人税中間納付 - @確定法人税額 - @確定地方法人税額), 0].max
      end

      # 中間納付した金額のうち税額として確定した額
      #
      def 法人税損金納付額
        [@法人税中間納付 + @地方法人税中間納付, @確定法人税額 + @確定地方法人税額].min
      end

      def 確定都道府県住民税
        @税額.dig(:kenmin, :kintou) + @税額.dig(:kenmin, :houjinzei)
      end

      def 期首未納都道府県民税
        readable(@start_balance.dig('5153')) || 0
      end

      def 期末未納都道府県民税
        readable(@bs_data.dig('5153')) || 0
      end

      def 未納都道府県民税期中増減
        r = LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '5153')
        [readable(r[:credit]['5153'] || 0), readable(r[:debit]['5153'] || 0)]
      end

      def 都道府県民税仮払納付
        [(@都道府県民税中間納付 - 確定都道府県住民税), 0].max
      end

      def 都道府県民税損金納付
        [[確定都道府県住民税, 0].max, @都道府県民税中間納付].min
      end

      def 確定市民税
        @税額.dig(:shimin, :kintou) - @税額.dig(:shimin, :houjinzei)
      end

      def 期首未納市民税
        readable(@start_balance.dig('5154')) || 0
      end

      def 期末未納市民税
        readable(@bs_data.dig('5154')) || 0
      end

      def 未納市民税期中増減
        r = LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '5154')
        [readable(r[:credit]['5154'] || 0), readable(r[:debit]['5154'] || 0)]
      end

      def 市民税仮払納付
        [0, (@市民税中間納付 - 確定市民税)].max
      end

      def 市民税損金納付
        [@市民税中間納付, [確定市民税, 0].max].min
      end

      def 別表五一期首差引金額
        期首繰越損益 + 期首納税充当金 - 期首未納法人税 - 期首未納都道府県民税 - 期首未納市民税
      end

      def 別表五一期末差引金額
        期末繰越損益 + 期末納税充当金 - 期末未納法人税 - 期末未納都道府県民税 - 期末未納市民税
      end

      def 別表五一期中減差引金額
        期首繰越損益 + @納税充当金期中減 - @法人税期中減 - @都道府県民税期中減 - @市民税期中減
      end

      def 別表五一期中増差引金額
        期末繰越損益 + @納税充当金期中増 - @法人税期中増 - @都道府県民税期中増 - @市民税期中増
      end

      def 期末未収税金(code)
        readable((@bs_data[code] || 0) * -1)
      end

      def 別表七各期青色損失
        tags = @繰越損失管理.records
                 .filter { |record| record['start_date'] > @end_date.prev_year(10) && record['end_date'] < @start_date }
                 .map do |record|
          deduction = record['decrease']&.filter{ |r| r['date'] >= @start_date }&.dig(0, 'val') || 0
          next if deduction == 0 && record['amount'] == 0

          %Q(<MCB00110>
          <MCB00120>
          #{render_attr('MCB00130', etax_date(record['start_date']))}
          #{render_attr('MCB00140', etax_date(record['end_date']))}
          </MCB00120>
          <MCB00150>
            <MCB00160><kubun_CD>1</kubun_CD></MCB00160>
          </MCB00150>
          #{render_attr('MCB00190', deduction + record['amount'])}
          #{render_attr('MCB00200', deduction)}
          #{render_attr('MCB00210', record['amount'])}
          </MCB00110)
        end
        tags.compact.join("\n")
      end

      def 期首資本金
        readable(@start_balance.dig('911')) || 0
      end

      def 期末資本金
        readable(@bs_data.dig('911')) || 0
      end

      def 別表五一期首資本
        期首資本金
      end

      def 別表五一期末資本
        期末資本金
      end

      def 期首未納消費税
        readable(@start_balance.dig('516')) || 0
      end

      def 期末未納消費税
        readable(@bs_data.dig('516')) || 0
      end

      def 未納消費税期中増減
        r = LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '516')
        [readable(r[:credit]['516'] || 0), readable(r[:debit]['516'] || 0)]
      end

      def 概況月(idx)
        @start_date.next_month(idx).month
      end

      def 概況月売上(idx)
        gaikyo_month(idx, 'A0')
      end

      def 概況月仕入(idx)
        gaikyo_month(idx, 'B11') + gaikyo_month(idx, 'B12')
      end

      def 概況月人件費(idx)
        gaikyo_month(idx, 'C11') + gaikyo_month(idx, 'C12') + gaikyo_month(idx, 'C13') + gaikyo_month(idx, 'C14')
      end

      def 概況月外注費(idx)
        gaikyo_month(idx, 'C10')
      end

      def 概況月源泉徴収(idx)
        target = @start_date.next_month(idx)
        readable(LucaBook::State.gross(target.year, target.month, code: '5191')[:credit]['5191'] || 0)
        + readable(LucaBook::State.gross(target.year, target.month, code: '5193')[:credit]['5193'] || 0)
      end

      def 概況源泉徴収
        readable(LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '5191')[:credit]['5191'] || 0)
        + readable(LucaBook::State.gross(@start_date.year, @start_date.month, @end_date.year, @end_date.month, code: '5193')[:credit]['5193'] || 0)
      end

      def gaikyo(code)
        case code
        when /^[0-9]/
          readable(@bs_data.dig(code) || 0)
        when /^[A-H]/
          readable(@pl_data.dig(code) || 0)
        else
          raise 'invalid code supplied'
        end
      end

      def gaikyo_month(index, code)
        readable(@monthly.dig(index, code) || 0)
      end

      def lib_path
        __dir__
      end
    end
  end
end
