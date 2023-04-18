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
      include Luca::Jp::Uchiwake

      @dirname = 'journals'
      @record_type = 'raw'

      def kani(export: false)
        set_pl(4)
        set_bs(4)
        @issue_date = Date.today
        @company = CGI.escapeHTML(config.dig('company', 'name'))
        @software = 'LucaJp'
        @shinkoku_kbn = '30' # 確定申告

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
          @form_vers = proc_version
          @version = @form_vers['proc']
          @都道府県民税法人税割中間納付 = prepaid_tax('1859')
          @都道府県民税均等割中間納付 = prepaid_tax('185A')
          @都道府県民税中間納付 = @都道府県民税法人税割中間納付 + @都道府県民税均等割中間納付
          @市民税法人税割中間納付 = prepaid_tax('185D')
          @市民税均等割中間納付 = prepaid_tax('185E')
          @市民税中間納付 = @市民税法人税割中間納付 + @市民税均等割中間納付
          @法人税期中増, @法人税期中減 = 未納法人税期中増減
          @都道府県民税期中増, @都道府県民税期中減 = 未納都道府県民税期中増減
          @市民税期中増, @市民税期中減 = 未納市民税期中増減
          @事業税期中増, @事業税期中減 = 未納事業税期中増減
          @事業税中間納付 = prepaid_tax('1854') + prepaid_tax('1855') + prepaid_tax('1856') + prepaid_tax('1857') + prepaid_tax('1858')
          @翌期還付法人税 = 中間還付税額(@確定法人税額 + @確定地方法人税額, @法人税中間納付 + @地方法人税中間納付)
          @概況売上 = gaikyo('A0')
          @form_sec = [
            'HOA112', 'HOA116', 'HOA201', 'HOA420', 'HOA511', 'HOA522', 別表七フォーム,
            'HOE200', 適用額明細フォーム,
            'HOI010', 有価証券内訳フォーム, 買掛金内訳フォーム, 'HOI100', 借入金内訳フォーム, 'HOI141', 地代家賃内訳フォーム, 雑益雑損失内訳フォーム,
            'HOK010'
            ].compact.map{ |c| form_rdf(c) }.join('')
          #@extra_form_sec = ['HOI040']
          @it = it_part
          @form_data = [
            別表一, 別表一次葉, 別表二, 別表四簡易, 別表五一, 別表五二, 別表七, 別表十五,
            適用額明細,
            預貯金内訳, 有価証券内訳, 買掛金内訳, 仮受金内訳, 借入金内訳, 役員報酬内訳, 地代家賃内訳, 雑益雑損失内訳,
            概況説明
            ].compact.join("\n")
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
        STDERR.puts "別表一： 「決算確定の日」などの追記が必要"
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
        @当期還付事業税 = 還付事業税
        @翌期還付事業税 = 中間還付税額(確定事業税, @事業税中間納付)
        @別表四調整所得 = @当期純損益 + @法人税等 - @納付事業税 - @翌期還付事業税 + @当期還付事業税

        @当期還付法人税 = refund_tax('1502')
        @当期還付都道府県住民税 = refund_tax('1503')
        @翌期還付都道府県住民税 = readable(@bs_data['1503']) || 0
        @当期還付市民税 = refund_tax('1505')
        @翌期還付市民税 = readable(@bs_data['1505']) || 0
        @事業税期首残高 = 期首未納事業税 > 0 ? 期首未納事業税 : (@当期還付事業税 * -1)
        @仮払税金 = [@翌期還付法人税, @翌期還付都道府県住民税, @翌期還付事業税, @翌期還付市民税]
                      .compact.sum

        render_erb(search_template('beppyo4.xml.erb'))
      end

      def 別表五一
        @期首資本金 = readable(@start_balance.dig('911'))
        @資本金期中減, @資本金期中増 = 純資産期中増減('911')
        @期首資本準備金, @期末資本準備金 = 期首期末残高('9131')
        @資本準備金期中減, @資本準備金期中増 = 純資産期中増減('9131')
        @期首その他資本剰余金, @期末その他資本剰余金 = 期首期末残高('9132')
        @その他資本剰余金期中減, @その他資本剰余金期中増 = 純資産期中増減('9132')
        @期首自己株式, @期末自己株式 = 期首期末残高('916')
        # 自己株式は負の純資産。借方集計は負の増加として認識
        @自己株式期中増, @自己株式期中減 = 純資産期中増減('916').map { |t| t * -1 }
        @資本金等の額期中減, @資本金等の額期中増 = 資本金等の額期中増減
        render_erb(search_template('beppyo51.xml.erb'))
      end

      def 別表五二
        @消費税中間納付額 = 消費税中間納付額 + 地方消費税中間納付額
        @当期還付消費税 = refund_tax('1501')
        @消費税期首残高 = 期首未納消費税 > 0 ? 期首未納消費税 : (@当期還付消費税 * -1)
        @翌期還付消費税 = 中間還付税額(@消費税期中増, @消費税中間納付額)
        @その他事業税 = 租税公課 - @消費税期中増
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
        STDERR.puts "別表十五： 交際費計上額なし。必要に応じて帳票削除" if @交際費 == 0
        @限度額 = @交際費 < 4_000_000 ? @交際費 : 4_000_000
        @不算入額 = @交際費 < 4_000_000 ? 0 : @交際費 - 4_000_000
        render_erb(search_template('beppyo15.xml.erb'))
      end

      def 適用額明細フォーム
        return nil if @確定法人税額 == 0

        'HOE990'
      end

      def 適用額明細
        if 期末資本金 <= 10_000_000
          STDERR.puts "適用額明細： 必要に応じて「少額減価償却資産の損金算入」（67条の5第1項, 00277。別表16[7]）の確認が必要"
        end
        if @確定法人税額 == 0
          STDERR.puts "別表一：適用額明細書の有無の確認が必要"
          return nil
        end

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
        @概況外注費 = gaikyo('C1O')
        @概況人件費 = gaikyo('C11') + gaikyo('C12') + gaikyo('C13')
        render_erb(search_template('gaikyo.xml.erb'))
      end

      def self.dict
        @@dict
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
        readable(debit_amount('C1I', @start_date.year, @start_date.month, @end_date.year, @end_date.month))
      end

      def 別表一同族区分
        case 同族会社?
        when nil
          nil
        when true
          '<kubun_CD>1</kubun_CD>'
        else
          '<kubun_CD>3</kubun_CD>'
        end
      end

      def 別表二同族区分
        case 同族会社?
        when nil
          nil
        when true
          '<kubun_CD>2</kubun_CD>'
        else
          '<kubun_CD>3</kubun_CD>'
        end
      end

      def 別表二株主リスト
        return '' if beppyo2_config('owners').nil?

        tags = beppyo2_config('owners')[1..-1]&.map.with_index(2) do |owner, i|
          %Q(<VAE00170>
          <VAE00180>
            <VAE00190>#{i}</VAE00190>
            <VAE00200>#{i}</VAE00200>
          </VAE00180>
            <VAE00210>
              #{render_attr('VAE00220', owner['address'])}
              #{render_attr('VAE00230', owner['name'])}
            </VAE00210>
            #{render_attr('VAE00235', owner['relation'] || '<kubun_CD>90</kubun_CD>')}
          <VAE00250>
          <VAE00290>
          #{render_attr('VAE00300', owner['shares'])}
                      <VAE00310>
                          #{render_attr('VAE00330', owner['votes'])}
                      </VAE00310>
          </VAE00290>
              </VAE00250>
          </VAE00170>)
        end
        tags.compact.join("\n")
      end

      def 別表二上位株数
        return nil if beppyo2_config('owners').nil?

        beppyo2_config('owners')[0..2].map{ |owner| owner['shares']&.to_i || 0 }.sum
      end

      def 別表二上位株割合
        return nil if beppyo2_config('total_shares').nil?
        return nil if beppyo2_config('owners').nil?

        total = if beppyo2_config('own_shares').nil?
                  beppyo2_config('total_shares')
                else
                  beppyo2_config('total_shares') - beppyo2_config('own_shares')
                end
        (別表二上位株数 * 100.0 / total).round(1)
      end

      def 別表二上位議決権数
        return nil if beppyo2_config('owners').nil?

        beppyo2_config('owners')[0..2].map{ |owner| owner['votes']&.to_i || 0 }.sum
      end

      def 別表二上位議決権割合
        return nil if beppyo2_config('total_votes').nil?
        return nil if beppyo2_config('owners').nil?

        total = if beppyo2_config('no_votes').nil?
                  beppyo2_config('total_votes')
                else
                  beppyo2_config('total_votes') - beppyo2_config('no_votes')
                end
        (別表二上位議決権数 * 100.0 / total).round(1)
      end

      # TODO: 特定同族会社の判定
      #
      def 同族会社?
        return nil if it_part_config('shihon_kin').nil?
        return nil if it_part_config('shihon_kin') > 100_000_000
        return nil if 別表二上位議決権割合.nil? || 別表二上位株割合.nil?

        return true if 別表二上位議決権割合 > 50 || 別表二上位株割合 > 50
        false
      end

      def 別表四還付法人税等金額
        refund_tax()
      end

      def 別表四還付事業税
        return nil if @当期還付事業税 == 0

        "<ARC00220><ARC00230>仮払事業税消却(未収計上した還付事業税)</ARC00230>#{render_attr('ARC00240', @当期還付事業税)}#{render_attr('ARC00250', @当期還付事業税)}</ARC00220>\n"
      end

      def 別表五一仮払税金
        未収仮払税金 = [@start_balance['1502'], @start_balance['1503'], @start_balance['1504'], @start_balance['1505']].compact.sum
        還付税金 = [@当期還付法人税, @当期還付都道府県住民税, @当期還付事業税, @当期還付市民税].compact.sum
        return '' if 未収仮払税金 == 0 && 還付税金 == 0 && @仮払税金 == 0

        %Q(<ICB00140>
        #{render_attr('ICB00150', '仮払税金')}
        #{render_attr('ICB00160', readable(未収仮払税金) * -1)}
        <ICB00170>
        #{render_attr('ICB00190', readable(還付税金) * -1)}
        #{render_attr('ICB00200', @仮払税金 * -1)}
        </ICB00170>
        #{render_attr('ICB00210', @仮払税金 * -1)}
        </ICB00140>)
      end

      def 別表五一還付法人税
        return '' if (@start_balance['1502']||0) == 0 && @翌期還付法人税 == 0

        %Q(<ICB00220>
        #{render_attr('ICB00230', readable(@start_balance['1502']) || 0)}
        <ICB00240>
        #{render_attr('ICB00250', @当期還付法人税)}
        #{render_attr('ICB00260', @翌期還付法人税)}
        </ICB00240>
        #{render_attr('ICB00270', @翌期還付法人税)}
        </ICB00220>)
      end

      def 別表五一還付都道府県住民税
        return '' if (@start_balance['1503']||0) == 0 && @翌期還付都道府県住民税 == 0

        %Q(<ICB00280>
        #{render_attr('ICB00290', readable(@start_balance['1503']) || 0)}
        <ICB00300>
        #{render_attr('ICB00310', @当期還付都道府県住民税)}
        #{render_attr('ICB00320', @翌期還付都道府県住民税)}
        </ICB00300>
        #{render_attr('ICB00330', @翌期還付都道府県住民税)}
        </ICB00280>)
      end

      def 別表五一還付市民税
        return '' if (@start_balance['1505']||0) == 0 && @翌期還付市民税 == 0

        %Q(<ICB00340>
        #{render_attr('ICB00350', readable(@start_balance['1505']) || 0)}
        <ICB00360>
        #{render_attr('ICB00370', @当期還付市民税)}
        #{render_attr('ICB00380', @翌期還付市民税)}
        </ICB00360>
        #{render_attr('ICB00390', @翌期還付市民税)}
        </ICB00340>)
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

      def 納税充当金期中減
        r = debit_amount('515', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        readable(r)
      end

      def 当期納税充当金
        readable(@pl_data.dig('H0')) - [法人税損金納付額, 都道府県民税損金納付, 市民税損金納付, 事業税損金納付].compact.sum
      end

      def 期首未納法人税
        readable(@start_balance.dig('5151')) || 0
      end

      def 期末未納法人税
        納付税額(@確定法人税額 + @確定地方法人税額, @法人税中間納付 + @地方法人税中間納付)
      end

      def 未納法人税期中増減
        r = debit_amount('5151', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        [(@確定法人税額 + @確定地方法人税額), readable(r)]
      end

      # 中間納付した金額のうち税額とならず、還付されるべき額
      #
      def 法人税仮払納付額
        [(@法人税中間納付 + @地方法人税中間納付 - @確定法人税額 - @確定地方法人税額), 0].max
      end

      # 中間納付した金額のうち税額として確定した額
      #
      def 法人税損金納付額
        @法人税中間納付 + @地方法人税中間納付 - 法人税仮払納付額
      end

      def 確定都道府県住民税
        readable(@pl_data['H112']) || 0
      end

      def 期首未納都道府県民税
        readable(@start_balance.dig('5153')) || 0
      end

      def 未納都道府県民税期中増減
        r = debit_amount('5153', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        [確定都道府県住民税, readable(r)]
      end

      def 都道府県民税仮払納付
        readable(@bs_data['1503']) || 0
      end

      # 期末納付済金額のうち税額として確定したもの
      #
      def 都道府県民税損金納付
        @都道府県民税均等割中間納付 + @都道府県民税法人税割中間納付 - 都道府県民税仮払納付
      end

      def 確定市民税
        readable(@pl_data['H113']) || 0
      end

      def 期首未納市民税
        readable(@start_balance.dig('5154')) || 0
      end

      def 期末未納市民税
        readable(@bs_data['5154']) || 0
      end

      def 未納市民税期中増減
        r = debit_amount('5154', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        [確定市民税, readable(r)]
      end

      def 市民税仮払納付
        readable(@bs_data['1505']) || 0
      end

      # 期末納付済金額のうち税額として確定したもの
      #
      def 市民税損金納付
        @市民税均等割中間納付 + @市民税法人税割中間納付 - 市民税仮払納付
      end

      def 確定事業税
        readable(@pl_data['H114']) || 0
      end

      def 事業税損金納付
        [@事業税中間納付, 確定事業税].min
      end

      def 別表五一期首差引金額
        [期首繰越損益, 期首納税充当金].compact.sum - [
          期首未納法人税,
          期首未納都道府県民税,
          期首未納市民税,
          @当期還付事業税
        ].compact.sum
      end

      def 別表五一期末差引金額
        [期末繰越損益, 当期納税充当金].compact.sum - [
          期末未納法人税,
          確定都道府県住民税,
          確定市民税,
          @翌期還付事業税
        ].compact.sum
      end

      def 別表五一期中減差引金額
        [期首繰越損益, 納税充当金期中減].compact.sum - [
          @法人税期中減,
          @都道府県民税期中減,
          @市民税期中減,
          @法人税中間納付,
          @地方法人税中間納付,
          @都道府県民税中間納付,
          @市民税中間納付,
          @当期還付事業税
        ].compact.sum
      end

      def 別表五一期中増差引金額
        [期末繰越損益, 納付税額(確定事業税, @事業税中間納付)].compact.sum - [
          @法人税中間納付,
          @地方法人税中間納付,
          @都道府県民税中間納付,
          @市民税中間納付,
          @翌期還付事業税
        ].compact.sum
      end

      def 期末未収税金(code)
        readable((@bs_data[code] || 0) * -1)
      end

      def 別表五一期首資本
        readable(@start_balance.dig('911')||0 + @start_balance.dig('913')||0)
      end

      # 資本金、資本準備金、その他資本剰余金、自己株式（控除）の合算
      #
      def 資本金等の額期中増減
        inc = ['911', '913'].map do |code|
          credit_amount(code, @start_date.year, @start_date.month, @end_date.year, @end_date.month) || 0
        end
        inc << (debit_amount('916', @start_date.year, @start_date.month, @end_date.year, @end_date.month)||0) * -1
        dec = ['911', '913'].map do |code|
          debit_amount(code, @start_date.year, @start_date.month, @end_date.year, @end_date.month) || 0
        end
        dec << (credit_amount('916', @start_date.year, @start_date.month, @end_date.year, @end_date.month)||0) * -1

        [readable(dec.sum), readable(inc.sum)]
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
          </MCB00110>)
        end
        tags.compact.join("\n")
      end

      def 期首未納消費税
        readable(@start_balance.dig('516')) || 0
      end

      def 期末未納消費税
        readable(@bs_data.dig('516')) || 0
      end

      def 未納消費税期中増減
        increase = debit_amount('C1I1', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        r = debit_amount('516', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        [readable(increase), readable(r)]
      end

      def 概況源泉徴収種類
        tags = []
        if credit_count('5191', @start_date.year, @start_date.month, @end_date.year, @end_date.month) > 0
          tags << render_attr('IAF03100', '<kubun_CD>1</kubun_CD>')
        end
        if credit_count('5193', @start_date.year, @start_date.month, @end_date.year, @end_date.month) > 0
          tags << render_attr('IAF03200', '<kubun_CD>1</kubun_CD>')
        elsif credit_count('5194', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
          tags << render_attr('IAF03200', '<kubun_CD>1</kubun_CD>')
        end
        tags.compact.join("\n")
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
        gaikyo_month(idx, 'C1O')
      end

      def 概況月源泉徴収(idx)
        target = @start_date.next_month(idx)
        [
          readable(credit_amount('5191', target.year, target.month, target.year, target.month)),
          readable(credit_amount('5193', target.year, target.month, target.year, target.month))
        ].sum
      end

      def 概況源泉徴収
        [
          readable(credit_amount('5191', @start_date.year, @start_date.month, @end_date.year, @end_date.month)),
          readable(credit_amount('5193', @start_date.year, @start_date.month, @end_date.year, @end_date.month))
        ].sum
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

      def proc_version
        if @end_date >= Date.parse('2022-4-1')
          { 'proc' => '22.0.3', 'HOA112' => '4.0', 'HOA116' => '3.0', 'HOA420' => '21.0', 'HOA511' => '14.0', 'HOA522' => '8.0', 'HOB710' => '12.0', 'HOE200' => '14.0', 'HOE990' => '6.1', 'HOK010' => '6.0' }
        elsif @end_date >= Date.parse('2021-4-1')
          { 'proc' => '21.0.2', 'HOA112' => '3.1', 'HOA116' => '2.0', 'HOA420' => '20.0', 'HOA511' => '13.0', 'HOA522' => '7.0', 'HOB710' => '11.0', 'HOE200' => '13.0', 'HOE990' => '5.0', 'HOK010' => '6.0' }
        else
          { 'proc' => '20.0.2', 'HOA112' => '2.0', 'HOA116' => '1.0', 'HOA420' => '19.0', 'HOA511' => '13.0', 'HOA522' => '6.0', 'HOB710' => '11.0', 'HOE200' => '13.0', 'HOE990' => '5.0', 'HOK010' => '5.0' }
        end
      end

      def lib_path
        __dir__
      end
    end
  end
end
