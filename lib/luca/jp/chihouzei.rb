# frozen_string_literal: true

require 'json'
require 'cgi/escape'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca/jp'

module Luca
  module Jp
    class Chihouzei < LucaBook::State
      include LucaSupport::View
      include Luca::Jp::Common
      include Luca::Jp::Util

      @dirname = 'journals'
      @record_type = 'raw'

      def kani(report_cfg, export: false, ext_config: nil)
        set_pl(4)
        set_bs(4)
        @issue_date = Date.today
        @software = 'LucaJp'
        @jimusho_name = report_cfg['jimusho_name']
        @report_category = report_cfg['type']
        @employee = report_cfg['employee'] || 1
        @office_count = report_cfg['office_count'] || 1
        # 自治体ごとの税率カスタマイズ
        @houjinzeiwari_rate = report_cfg['houjinzeiwari']
        @shotoku399 = report_cfg['shotoku399']
        @shotoku401 = report_cfg['shotoku401']
        @shotoku801 = report_cfg['shotoku801']

        別表四所得調整(ext_config)
        @税額 = 税額計算
        jichitai = @report_category == 'city' ? :shimin : :kenmin
        @均等割 = report_cfg['kintouwari'] || @税額.dig(jichitai, :kintou)
        @確定法人税割 = @税額.dig(jichitai, :houjinzei)
        @地方特別法人事業税中間納付 = prepaid_tax('1854', @jimusho_name)
        @所得割中間納付 = prepaid_tax('1855', @jimusho_name)
        @法人税割中間納付 = prepaid_tax(
          @report_category == 'city' ? '185D' : '1859',
          @jimusho_name
        )
        @均等割中間納付 = prepaid_tax(
          @report_category == 'city' ? '185E' : '185A',
          @jimusho_name
        )
        @所得割 = @税額.dig(:kenmin, :shotoku)
        if export
          {
            customer: @jimusho_name,
            juminzei: {
              kinto: {
                zeigaku: @均等割,
                chukan: @均等割中間納付
              },
              houjinzei: {
                zeigaku: @確定法人税割,
                chukan: @法人税割中間納付
              }
            }
          }.tap do |record|
            if @report_category != 'city'
              record[:jigyouzei] = {
                shotoku: {
                  zeigaku: @所得割,
                  chukan: @所得割中間納付
                },
                tokubetsu: {
                  zeigaku: @税額.dig(:kenmin, :tokubetsu),
                  chukan: @地方特別法人事業税中間納付
                },
              }
            end
          end
        else
          @company = CGI.escapeHTML(config.dig('company', 'name'))
          @form_vers = proc_version
          @jichitai_code = report_cfg['jichitai_code']
          @jimusho_code = report_cfg['jimusho_code']
          @kanri_bango = report_cfg['x_houjin_bango']
          @app_version = report_cfg['app_version']
          @address = report_cfg['address'] || it_part_config('nozeisha_adr')
          @jigyosho_name = report_cfg['name'] || '本店'
          @procedure_code = 'R0102100'
          @procedure_name = '法人都道府県民税・事業税・特別法人事業税又は地方法人特別税　確定申告'
          @form_sec = case @report_category
                      when 'prefecture'
                        ["R0102AA#{@form_vers['R0102AA']}", 別表九フォーム]
                          .compact.map{ |c| form_attr(c) }.join('')
                      when '23ku'
                        ["R0102AA#{@form_vers['R0102AA']}", "R0102AG#{@form_vers['R0102AG']}", 別表九フォーム]
                          .compact.map{ |c| form_attr(c) }.join('')
                      when 'city'
                        ["R0504AA180"].compact.map{ |c| form_attr(c) }.join('')
                      end
          @user_inf = render_erb(search_template('eltax-userinf.xml.erb'))
          @form_data = case @report_category
                       when 'prefecture'
                         [第六号, 別表九].compact.join("\n")
                       when '23ku'
                         [第六号, 別表四三, 別表九].compact.join("\n")
                       when 'city'
                         [第二十号].compact.join("\n")
                       end
          render_erb(search_template('eltax.xml.erb'))
        end
      end

      def export_json(report_cfg, ext_config: nil)
        records = kani(report_cfg, export: true, ext_config: ext_config)
        label = @report_category == 'city' ? '市町村住民税' : '都道府県住民税'
        {}.tap do |item|
          item['date'] = @end_date
          item['debit'] = []
          item['credit'] = []
          unless @report_category == 'city'
            records[:jigyouzei].each do |k, dat|
              if dat[:chukan] > 0
                item['credit'] << { 'label' => karibarai_label(k, @report_category), 'amount' => dat[:chukan] }
              end
              if dat[:chukan] > dat[:zeigaku]
                item['debit'] << { 'label' => '未収地方事業税', 'amount' => dat[:chukan] - dat[:zeigaku] }
              else
                item['credit'] << { 'label' => '未払地方事業税', 'amount' => dat[:zeigaku] - dat[:chukan] }
              end
              item['debit'] << { 'label' => '地方事業税', 'amount' => dat[:zeigaku] } if dat[:zeigaku] > 0
            end
          end
          records[:juminzei].each do |k, dat|
            if dat[:chukan] > 0
              item['credit'] << { 'label' => karibarai_label(k, @report_category), 'amount' => dat[:chukan] }
            end
            if dat[:chukan] > dat[:zeigaku]
              item['debit'] << { 'label' => "未収#{label}", 'amount' => dat[:chukan] - dat[:zeigaku] }
            else
              item['credit'] << { 'label' => "未払#{label}", 'amount' => dat[:zeigaku] - dat[:chukan] }
            end
            item['debit'] << { 'label' => label, 'amount' => dat[:zeigaku] } if dat[:zeigaku] > 0
          end
          item['x-customer'] = records[:customer] unless records[:customer].nil?
          item['x-editor'] = 'LucaJp'
        end
      end

      def 第六号
        @資本金準備金 = readable(['911', '9131'].map { |cd| @bs_data.dig(cd) }.compact.sum)
        STDERR.puts "第六号様式： 「決算確定の日」などの追記が必要。「国外関連者」の確認が必要"
        render_erb(search_template('el-no6.xml.erb'))
      end

      def 別表四三
        @office_23ku = config.dig('jp', 'eltax', 'office_23ku')
        render_erb(search_template('el-no6-43.xml.erb'))
      end

      def 第二十号
        @資本金準備金 = readable(['911', '9131'].map { |cd| @bs_data.dig(cd) }.compact.sum)
        render_erb(search_template('el-no20.xml.erb'))
      end

      def 別表九フォーム
        return nil if @繰越損失管理.records.length == 0

        "R0102AM#{@form_vers['R0102AM']}"
      end

      def 別表九
        return nil if @繰越損失管理.records.length == 0

        render_erb(search_template('el-no6-9.xml.erb'))
      end

      private

      def 法人税割課税標準
        case Luca::Jp::Util.eltax_config('reports')
               .filter { |r| レポート種別.include?(r['type']) }.length
        when 0, 1
          (@税額.dig(:houjin, :kokuzei) / 1000).floor * 1000
        else
          従業員数による分割課税標準 @税額.dig(:houjin, :kokuzei)
        end
      end

      def 事業税中間納付
        @所得割中間納付
      end

      # 災害損失は考慮していない
      #
      def 別表九各期青色損失
        tags = @繰越損失管理.records
                 .filter { |record| record['start_date'] > @end_date.prev_year(10) && record['end_date'] < @start_date }
                 .map do |record|
          deduction = record['decrease']&.filter{ |r| r['date'] >= @start_date }&.dig(0, 'val') || 0
          next if deduction == 0 && record['amount'] == 0

          %Q(<AMB00200>
          <AMB00210>#{etax_date(@start_date)}</AMB00210>
          <AMB00220>#{etax_date(@end_date)}</AMB00220>
          <AMB00225>1</AMB00225>
          #{render_attr('AMB00230', deduction + record['amount'])}
          #{render_attr('AMB00240', deduction)}
          #{render_attr('AMB00250', record['amount'])}
          </AMB00200>)
        end
        return tags.compact.join("\n") if tags.length > 0

        %Q(<AMB00200>
        <AMB00210><gen:era /><gen:yy /><gen:mm /><gen:dd /></AMB00210>
        <AMB00220><gen:era /><gen:yy /><gen:mm /><gen:dd /></AMB00220>
        <AMB00225 />
        <AMB00230 />
        <AMB00240 />
        <AMB00250 />
        </AMB00200>)
      end

     def eltax_kouza
       items = it_part_config('kanpu_kinyukikan').split('-')
       %Q(<gen:kubun_CD />
       <gen:kinyukikan_NM>#{items[0]}</gen:kinyukikan_NM>
          <gen:shiten_NM>#{items[1]}</gen:shiten_NM>
       <gen:kinyukikan_CD />
       <gen:shiten_CD />
       <gen:yokin>1</gen:yokin>
          <gen:koza>#{items[3]}</gen:koza>)
     end

      def form_attr(code)
        name = {
          'R0102AA' => '中間・確定申告書',
          'R0102AG' => '均等割額の計算に関する明細書',
          'R0102AM' => '欠損金額等及び災害損失金の控除明細書'
        }[code[0,7]]
        "<FORM_ATTR><FORM_ID>#{code}</FORM_ID><FORM_NAME>#{name}</FORM_NAME><FORM_FILE_NAME></FORM_FILE_NAME><FORM_XSL_NAME></FORM_XSL_NAME></FORM_ATTR>"
      end

      def karibarai_label(key, category)
        if category == 'city'
          case key
          when :houjinzei
            '仮払市民税法人税割'
          when :kinto
            '仮払市民税均等割'
          end
        else
          case key
          when :tokubetsu
            '仮払地方税特別法人事業税'
          when :shotoku
            '仮払地方税所得割'
          when :syunyu
            '仮払地方税収入割'
          when :shihon
            '仮払地方税資本割'
          when :fukakachi
            '仮払地方税付加価値割'
          when :houjinzei
            '仮払地方税法人税割'
          when :kinto
            '仮払地方税均等割'
          end
        end
      end

      def proc_version
        if @end_date >= Date.parse('2022-4-1')
          { 'R0102AA' => '211', 'R0102AG' => '211', 'R0102AM' => '211' }
        elsif @start_date >= Date.parse('2020-4-1')
          { 'R0102AA' => '200', 'R0102AG' => '120','R0102AM' => '200' }
        else
          { 'R0102AA' => '190', 'R0102AG' => '120', 'R0102AM' => '190' }
        end
      end

      def lib_path
        __dir__
      end
    end
  end
end
