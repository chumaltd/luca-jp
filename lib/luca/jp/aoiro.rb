# frozen_string_literal: true

require 'json'
require 'cgi/escape'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
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

      def kani(ext_config: nil, export: false, no_xbrl: false, kessanbi: nil)
        set_pl(4)
        set_bs(4)
        @issue_date = Date.today
        @kessanbi = kessanbi
        @company = CGI.escapeHTML(config.dig('company', 'name'))
        @software = 'LucaJp'
        @shinkoku_kbn = '30' # 確定申告
        @no_xbrl = no_xbrl # 決算書XBRLの組み込み省略

        別表四所得調整(ext_config)
        @税額 = 税額計算
        @確定法人税額 = @税額.dig(:houjin, :kokuzei)
        @法人税額 = 中小企業の軽減税額 + 一般区分の税額
        @地方法人税課税標準 = (@法人税額 / 1000).floor * 1000
        @地方法人税額 = 地方法人税額(@地方法人税課税標準)
        @確定地方法人税額 = @税額.dig(:houjin, :chihou)

        @所得税等の仮払額 = prepaid_tax('185F')
        @所得税等の税額控除額 = [
          @所得税等の仮払額,
          @所得税等の損金不算入額
        ].compact.sum
        @法人税中間納付 = prepaid_tax('1851')
        @地方法人税中間納付 = prepaid_tax('1852')
        @所得税等の還付額 = [@所得税等の税額控除額 - @確定法人税額, 0].max
        @差引所得に対する法人税額 = [@確定法人税額 - @所得税等の税額控除額, 0].max
        @法人税中間納付の還付額 = [@法人税中間納付 - @差引所得に対する法人税額, 0].max
        @法人税未払 = [@差引所得に対する法人税額 - @法人税中間納付, 0].max

        if export
          @繰越損失管理.save unless @繰越損失管理.nil?
          {
            kokuzei: {
              zeigaku: @確定法人税額,
              shotoku: {
                karibarai: @所得税等の仮払額,
                kanpu: @所得税等の還付額,
                modori: [@所得税等の還付額 - @所得税等の仮払額, 0].max
              },
              chukan: {
                karibarai: @法人税中間納付,
                kanpu: @法人税中間納付の還付額
              },
              mibarai: @法人税未払
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
          @翌期還付法人税 = 中間還付税額(@確定法人税額 + @確定地方法人税額, @法人税中間納付 + @地方法人税中間納付)
          @概況売上 = gaikyo('A0')
          @form_sec = [
            'HOA112', 'HOA116', 'HOA201', 'HOA420', 'HOA511', 'HOA522',
            別表六一フォーム, 別表七フォーム, 別表八一フォーム, 別表十四二フォーム, 別表十五フォーム,
            適用額明細フォーム,
            'HOI010', 有価証券内訳フォーム, 買掛金内訳フォーム, 'HOI100', 借入金内訳フォーム, 'HOI141', 地代家賃内訳フォーム, 雑益雑損失内訳フォーム,
            'HOK010'
            ].compact.map{ |c| form_rdf(c) }.join('')
          #@extra_form_sec = ['HOI040']
          @it = it_part
          @form_data = [
            別表一, 別表一次葉, 別表二, 別表四簡易, 別表五一, 別表五二,
            別表六一, 別表七, 別表八一, 別表十四二, 別表十五,
            適用額明細,
            預貯金内訳, 有価証券内訳, 買掛金内訳, 仮受金内訳, 借入金内訳, 役員報酬内訳, 地代家賃内訳, 雑益雑損失内訳,
            概況説明, 決算書
            ].compact.join("\n")
          render_erb(search_template('aoiro.xtx.erb'))
        end
      end

      def export_json(ext_config: nil, raw: false)
        dat = kani(export: true, ext_config: ext_config)
        item = {
          'date' => @end_date,
          'debit' => [],
          'credit' => [],
          'x-editor' => 'LucaJp'
        }
        item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:kokuzei][:zeigaku] }
        確定仕訳所得税(item, dat)
        確定仕訳国税(item, dat)
        item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:chihou][:zeigaku] } if dat[:chihou][:zeigaku] > 0
        確定仕訳地方税(item, dat)
        res = [item]

        raw ? res : JSON.dump(res)
      end

      def 確定仕訳所得税(item, dat)
        if dat.dig(:kokuzei, :shotoku, :karibarai) > 0
          item['credit'] << { 'label' => '仮払所得税', 'amount' => dat[:kokuzei][:shotoku][:karibarai] }
        end
        if dat[:kokuzei][:shotoku][:kanpu] > 0
          item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:kokuzei][:shotoku][:kanpu] }
        end
        if dat[:kokuzei][:shotoku][:modori] > 0
          # TODO: 損金経理する所得税の補助科目追加
          item['credit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:kokuzei][:shotoku][:modori] }
        end
      end

      def 確定仕訳国税(item, dat)
        if dat.dig(:kokuzei, :chukan, :karibarai) > 0
          item['credit'] << { 'label' => '仮払法人税', 'amount' => dat[:kokuzei][:chukan][:karibarai] }
        end
        if dat.dig(:kokuzei, :chukan, :kanpu) > 0
          item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:kokuzei][:chukan][:kanpu] }
        end
        if dat[:kokuzei][:mibarai] > 0
          item['credit'] << { 'label' => '未払法人税', 'amount' => dat[:kokuzei][:mibarai] }
        end
      end

      def 確定仕訳地方税(item, dat)
        if dat[:chihou][:chukan] > 0
          item['credit'] << { 'label' => '仮払法人税(地方)', 'amount' => dat[:chihou][:chukan] }
        end
        if dat[:chihou][:chukan] > dat[:chihou][:zeigaku]
          item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:chihou][:chukan] - dat[:chihou][:zeigaku] }
        else
          item['credit'] << { 'label' => '未払法人税', 'amount' => dat[:chihou][:zeigaku] - dat[:chihou][:chukan] }
        end
      end

      def 別表一
        STDERR.puts "別表一： 「決算確定の日」などの追記、または --kessan オプション指定が必要" if @kessanbi.nil?
        render_erb(search_template('beppyo1.xml.erb'))
      end

      def 別表一次葉
        @消費税期中増, @消費税期中減 = 未納消費税期中増減
        render_erb(search_template('beppyo1-next.xml.erb'))
      end

      def 別表二
        render_erb(search_template('beppyo2.xml.erb'))
      end

      # NOTE: 別表四所得調整に依存
      def 別表四簡易
        @当期純損益 = readable(@pl_data.dig('HA'))

        ### 損金不算入額の計算

        @損金経理をした法人税及び地方法人税 = 法人税損金納付額
        @損金経理をした道府県民税及び市町村民税 = [
          都道府県民税損金納付,
          市民税損金納付,
        ].compact.sum
        @損金経理をした納税充当金 = 当期納税充当金
        @損金不算入額 = [
          @損金不算入額税額未確定,
          @損金経理をした法人税及び地方法人税,
          @損金経理をした道府県民税及び市町村民税,
          @損金経理をした納税充当金,
        ].compact.sum
        @損金不算入額留保 = [
          @減価償却の償却超過額,
          @当期還付事業税,
          @損金経理をした法人税及び地方法人税,
          @損金経理をした道府県民税及び市町村民税,
          @損金経理をした納税充当金,
        ].compact.sum
        @損金不算入額社外流出 = [
          @役員給与の損金不算入額,
          @交際費等の損金不算入額,
          # TODO: 附帯税
        ].compact.sum

        ### 益金不算入額の計算

        @翌期還付事業税 = ['1504', '1854', '1855', '1856', '1857', '1858']
                            .map{ |code| readable(@bs_data[code]) }
                            .compact.sum
        @益金不算入額 = [
          @益金不算入額税額未確定,
          # NOTE: 確定税額は会計上も費用認識しているため相殺
          (@事業税中間納付 * -1),
          @翌期還付事業税
        ].compact.sum
        @益金不算入額留保 = [
          @納付事業税,
          @減価償却超過額の当期認容額,
          @翌期還付事業税
        ].compact.sum
        @益金不算入額社外流出 = [
          # TODO: 欠損金繰戻還付、欠損金当期控除
          @受取配当金の益金不算入額,
          @受贈益の益金不算入額,
        ].compact.sum
        # TODO: 外国法人税の損金不算入調整

        render_erb(search_template('beppyo4.xml.erb'))
      end

      def 別表五一
        @当期還付法人税 = refund_tax('1502')
        @当期還付都道府県住民税 = refund_tax('1503')
        @当期還付市民税 = refund_tax('1505')
        @翌期還付都道府県住民税 = readable(@bs_data['1503']) || 0
        @翌期還付市民税 = readable(@bs_data['1505']) || 0

        @期首資本金 = readable(@start_balance.dig('911')) || 0
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
        @事業税期首残高 = 期首未納事業税 > 0 ? 期首未納事業税 : (@当期還付事業税 * -1)
        @その他事業税 = 租税公課 - @消費税期中増
        render_erb(search_template('beppyo52.xml.erb'))
      end

      def 別表六一フォーム
        return nil if @所得税等の税額控除額 <= 0

        'HOB016'
      end

      def 別表六一
        return nil if @所得税等の税額控除額 <= 0

        STDERR.puts "別表六一「所得税額の控除に関する明細書」： 受取配当金など所得税額控除の収入金額追記、内訳の追加"
        render_erb(search_template('beppyo6-1.xml.erb'))
      end

      def 別表七フォーム
        return nil if @繰越損失管理.records.length == 0

        'HOB710'
      end

      def 別表七
        return nil if @繰越損失管理.records.length == 0

        render_erb(search_template('beppyo7.xml.erb'))
      end

      def 別表八一フォーム
        return nil unless @受取配当金の益金不算入額

        'HOB800'
      end

      def 別表八一
        return nil unless @受取配当金の益金不算入額

        STDERR.puts "別表八（一）「受取配当等の益金算入に関する明細書」： 受取配当額や明細の追記が必要"
        render_erb(search_template('beppyo8-1.xml.erb'))
      end

      def 別表十四二フォーム
        return nil if readable(@pl_data.dig('C1X')||0) <= 0

        'HOE099'
      end

      def 別表十四二
        @寄付金 = readable(@pl_data.dig('C1X')||0)
        return nil if @寄付金 <= 0

        STDERR.puts "別表十四（二）「寄附金の損金算入に関する明細書」： 損金算入可能な寄付金の明細追記が必要"
        @指定寄付金 = readable(@pl_data.dig('C1X1')||0)
        render_erb(search_template('beppyo14-2.xml.erb'))
      end

      def 別表十五フォーム
        return nil if readable(@pl_data.dig('C1B') || 0) <= 0

        'HOE200'
      end

      def 別表十五
        @交際費 = readable(@pl_data.dig('C1B') || 0)
        return nil if @交際費 <= 0

        STDERR.puts "別表十五「交際費等の損金算入に関する明細書」： 飲食費など明細の追記が必要"
        @限度額 = @交際費 < 4_000_000 ? @交際費 : 4_000_000
        @不算入額 = @交際費 < 4_000_000 ? 0 : @交際費 - 4_000_000
        render_erb(search_template('beppyo15.xml.erb'))
      end

      def 適用額明細フォーム
        return nil if 中小企業の軽減税率対象所得(所得金額) == 0

        'HOE990'
      end

      def 適用額明細
        unless 軽減税率不適用法人
          STDERR.puts "適用額明細： 必要に応じて「少額減価償却資産の損金算入」（67条の5第1項, 00277。別表16[7]）の確認が必要"
        end
        return nil if 適用額明細フォーム.nil?

        render_erb(search_template('tekiyougaku.xml.erb'))
      end

      def 概況説明
        @概況粗利益 = gaikyo('BA')
        @概況役員報酬 = gaikyo('C11')
        @概況給料 = gaikyo('C12')
        @概況交際費 = gaikyo('C1B')
        @概況減価償却 = gaikyo('C1P')
        chidai_accounts = @form_vers['HOK010'] >= '6.0' ? ['C1E'] : ['C1E', 'C1I']
        @概況地代租税 = chidai_accounts.map { |k| gaikyo(k) }.compact.sum
        @概況営業損益 = gaikyo('CA')
        @概況特別利益 = gaikyo('F0')
        @概況特別損失 = gaikyo('G0')
        @概況税引前損益 = gaikyo('GA')
        @概況資産計 = gaikyo('5')
        @概況現預金 = gaikyo('10')
        @概況受取手形 = gaikyo('120')
        @概況売掛金 = gaikyo('130')
        @概況棚卸資産 = gaikyo('160')
        @概況貸付金 = ['140', '333'].map { |k| gaikyo(k) }.compact.sum
        @概況建物 = gaikyo('311')
        @概況機械 = gaikyo('313')
        @概況車船 = ['314', '318'].map { |k| gaikyo(k) }.compact.sum
        @概況土地 = gaikyo('316')
        @概況負債計 = gaikyo('8ZZ')
        @概況支払手形 = gaikyo('510')
        @概況買掛金 = gaikyo('511')
        @概況個人借入金 = gaikyo('5121')
        @概況ほか借入金 =  gaikyo('512') - gaikyo('5121')
        @概況純資産 = gaikyo('9ZZ')
        @代表者報酬 = gaikyo('C11')
        @代表者借入 = gaikyo('5121')
        @概況仕入 = ['B11', 'B12'].map { |k| gaikyo(k) }.compact.sum
        @概況外注費 = gaikyo('C1O')
        @概況人件費 = ['C11', 'C12', 'C13'].map { |k| gaikyo(k) }.compact.sum
        render_erb(search_template('gaikyo.xml.erb'))
      end

      def 決算書フォーム
        return %Q(<XBRL2_1_SEC/>) if @no_xbrl

        xsd_filename = %Q(#statement-#{@issue_date.to_s}.xsd)
        %Q(<XBRL2_1_SEC><rdf:Seq>
          <rdf:li><rdf:description><Instance><rdf:Bag><rdf:li><rdf:description about="#HOT010-1"/></rdf:li></rdf:Bag></Instance></rdf:description></rdf:li>
          <rdf:li><rdf:description><taxonomy><rdf:Bag><rdf:li><rdf:description about="#{xsd_filename}"/></rdf:li></rdf:Bag></taxonomy></rdf:description></rdf:li>
          </rdf:Seq></XBRL2_1_SEC>)
      end

      def 決算書
        if @no_xbrl
          STDERR.puts "決算書XBRLをeTaxソフトに追加インポートする必要あり"
          return nil
        end

        @xbrl_filename = %Q(statement-#{@issue_date.to_s})
        @xbrl, @xsd = LucaBook::State.range(@start_date.year, @start_date.month, @end_date.year, @end_date.month)
                          .render_xbrl(@xbrl_filename)
        render_erb(search_template('xbrl21.xml.erb'))
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

      # 加算・減算欄の調整
      def 別表四調整所得仮計
        損金不算入額仮計 = [
          @減価償却の償却超過額,
          @役員給与の損金不算入額,
          @交際費等の損金不算入額,
          @当期還付事業税
        ].compact.sum

        益金不算入額仮計 = [
          @納付事業税,
          @事業税中間納付,
          @減価償却超過額の当期認容額,
          @受取配当金の益金不算入額,
          @受贈益の益金不算入額,
        ].compact.sum

        @税引前損益 + 損金不算入額仮計 - 益金不算入額仮計
      end

      def 別表四調整所得仮計留保
        @当期純損益 + @損金不算入額留保 - @益金不算入額留保
      end

      # NOTE: 別表四社外流出欄の本書と外書の区分は紙の事務を前提としており自明ではない。
      # 帳票フィールド仕様書を参照して実装するほかない
      #
      def 別表四調整所得仮計社外流出
        @損金不算入額社外流出
      end

      def 別表四調整所得仮計社外流出外書
        @益金不算入額社外流出 * -1
      end

      # 損金経理した税額控除対象額の調整
      def 別表四調整所得合計
        [
          別表四調整所得仮計,
          寄付金の損金不算入額,
          @所得税等の損金不算入額,
        ].compact.sum
      end

      def 別表四調整所得合計留保
        別表四調整所得仮計留保
      end

      def 別表四調整所得合計社外流出
        [
          別表四調整所得仮計社外流出,
          寄付金の損金不算入額,
          @所得税等の損金不算入額,
        ].compact.sum
      end

      def 別表四調整所得合計社外流出外書
        別表四調整所得仮計社外流出外書
      end

      def 別表四還付法人税等金額
        refund_tax()
      end

      def 別表四還付事業税
        return nil if @当期還付事業税 == 0

        "<ARC00220><ARC00230>仮払事業税消却(未収計上した還付事業税)</ARC00230>#{render_attr('ARC00240', @当期還付事業税)}#{render_attr('ARC00250', @当期還付事業税)}</ARC00220>\n"
      end

      def 別表五一仮払事業税
        return '' if @当期還付事業税 == 0 && @翌期還付事業税 == 0

        %Q(<ICB00140>
          #{render_attr('ICB00150', '仮払事業税')}
          #{render_attr('ICB00160', @当期還付事業税 * -1)}
            <ICB00170>
          #{render_attr('ICB00190', @当期還付事業税 * -1)}
          #{render_attr('ICB00200', @翌期還付事業税 * -1)}
            </ICB00170>
          #{render_attr('ICB00210', @翌期還付事業税 * -1)}
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
        r = credit_amount('515', @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        readable(r)
      end

      def 期末納税充当金
        readable(@bs_data.dig('515')) || 0
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
      # 決算後において、未収法人税・仮払法人税・仮払法人税(地方)の合計金額の想定
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

      # 決算後において、仮払地方税法人税割・仮払地方税均等割の金額は
      # 本来都道府県と市区町村に区分すべきだが、全額市民税とみなしている
      #
      def 都道府県民税仮払納付
        [
          readable(@bs_data['1503']),
          readable(@bs_data['1859']),
          readable(@bs_data['185A']),
        ].compact.sum
      end

      # 期末納付済金額のうち税額として確定したもの
      #
      def 都道府県民税損金納付
        @都道府県民税均等割中間納付 + @都道府県民税法人税割中間納付 - 都道府県民税仮払納付
      end

      def 期末未納都道府県民税
        readable(@bs_data.dig('5153')) || 0
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
        [
          readable(@bs_data['1505']),
          readable(@bs_data['185D']),
          readable(@bs_data['185E']),
        ].compact.sum
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
        [
          @当期還付法人税,
          @当期還付都道府県住民税,
          @当期還付市民税,
          期首繰越損益,
          期首納税充当金
        ].compact.sum - [
          期首未納法人税,
          期首未納都道府県民税,
          期首未納市民税,
          @当期還付事業税
        ].compact.sum
      end

      def 別表五一期末差引金額
        [
          @翌期還付法人税,
          @翌期還付都道府県住民税,
          @翌期還付市民税,
          期末繰越損益,
          期末納税充当金
        ].compact.sum - [
          期末未納法人税,
          期末未納都道府県民税,
          期末未納市民税,
          @翌期還付事業税
        ].compact.sum
      end

      def 別表五一期中減差引金額
        [
          @当期還付法人税,
          @当期還付都道府県住民税,
          @当期還付市民税,
          期首繰越損益,
          納税充当金期中減
        ].compact.sum - [
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
        [
          @翌期還付法人税,
          @翌期還付都道府県住民税,
          @翌期還付市民税,
          期末繰越損益,
          期末納税充当金
        ].compact.sum - [
          @法人税中間納付,
          @地方法人税中間納付,
          期末未納法人税,
          @都道府県民税中間納付,
          期末未納都道府県民税,
          @市民税中間納付,
          期末未納市民税,
          @翌期還付事業税
        ].compact.sum
      end

      def 期末未収税金(code)
        readable((@bs_data[code] || 0) * -1)
      end

      def 別表五一期首資本
        readable(['911', '913', '916'].map { |k| @start_balance.dig(k) }.compact.sum)
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
        ['B11', 'B12']
          .map { |k| gaikyo_month(idx, k) }.compact.sum
      end

      def 概況月人件費(idx)
        ['C11', 'C12', 'C13', 'C14']
          .map { |k| gaikyo_month(idx, k) }.compact.sum
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
        init_version = {
          'HOA201' => '4.0',
          'HOA511' => '13.0',
          'HOB710' => '11.0',
          'HOE200' => '13.0',
          'HOE990' => '5.0',
          'HOI090' => '4.0',
          'HOI100' => '5.0',
          'HOI150' => '3.0',
          'HOI160' => '3.0',
        }
        if @end_date >= Date.parse('2024-4-1')
          { 'proc' => '24.0.2', 'HOA112' => '6.0', 'HOA116' => '4.0', 'HOA201' => '5.0', 'HOA420' => '23.0', 'HOA511' => '15.0', 'HOA522' => '9.0', 'HOB710' => '13.0', 'HOE200' => '14.0', 'HOE990' => '7.0', 'HOI090' => '5.0', 'HOI100' => '6.0', 'HOI150' => '4.0', 'HOI160' => '4.0', 'HOK010' => '7.0' }
        elsif @end_date >= Date.parse('2023-4-1')
          init_version.merge({ 'proc' => '23.0.2', 'HOA112' => '5.0', 'HOA116' => '4.0', 'HOA201' => '5.0', 'HOA420' => '22.0', 'HOA511' => '14.0', 'HOA522' => '9.0', 'HOB710' => '13.0', 'HOE200' => '14.0', 'HOE990' => '7.0', 'HOK010' => '6.0' })
        elsif @end_date >= Date.parse('2022-4-1')
          init_version.merge({ 'proc' => '22.0.3', 'HOA112' => '4.0', 'HOA116' => '3.0', 'HOA420' => '21.0', 'HOA511' => '14.0', 'HOA522' => '8.0', 'HOB710' => '12.0', 'HOE200' => '14.0', 'HOE990' => '6.1', 'HOK010' => '6.0' })
        elsif @end_date >= Date.parse('2021-4-1')
          init_version.merge({ 'proc' => '21.0.2', 'HOA112' => '3.1', 'HOA116' => '2.0', 'HOA420' => '20.0', 'HOA522' => '7.0', 'HOK010' => '6.0' })
        else
          init_version.merge({ 'proc' => '20.0.2', 'HOA112' => '2.0', 'HOA116' => '1.0', 'HOA420' => '19.0', 'HOA522' => '6.0', 'HOK010' => '5.0' })
        end
      end

      def lib_path
        __dir__
      end
    end
  end
end
