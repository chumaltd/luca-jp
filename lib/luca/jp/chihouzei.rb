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
    class Chihouzei < LucaBook::State
      include LucaSupport::View
      include Luca::Jp::Common
      include Luca::Jp::Util

      @dirname = 'journals'
      @record_type = 'raw'

      def kani(export: false)
        set_pl(4)
        set_bs(4)
        @issue_date = Date.today
        @company = CGI.escapeHTML(config.dig('company', 'name'))
        @software = 'LucaJp'
        @jimusho_code = eltax_config('jimusho_code')
        @jimusho_name = eltax_config('jimusho_name')
        @app_version = eltax_config('app_version')
        @form_vers = proc_version

        @税額 = 税額計算
        @均等割 = @税額.dig(:kenmin, :kintou)
        @確定法人税割 = (@税額.dig(:kenmin, :houjinzei) / 100).floor * 100
        @地方特別法人事業税中間納付 = prepaid_tax('1854')
        @所得割中間納付 = prepaid_tax('1855')
        @法人税割中間納付 = prepaid_tax('1859')
        @均等割中間納付 = prepaid_tax('185A')
        @所得割 = @税額.dig(:kenmin, :shotoku)
        if export
          {
            jigyouzei: {
              shotoku: {
                zeigaku: @所得割,
                chukan: @所得割中間納付
              },
              tokubetsu: {
                zeigaku: @税額.dig(:kenmin, :tokubetsu),
                chukan: @地方特別法人事業税中間納付
              },
            },
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
          }
        else
          @procedure_code = 'R0102100'
          @procedure_name = '法人都道府県民税・事業税・特別法人事業税又は地方法人特別税　確定申告'
          @form_sec = ["R0102AA#{@form_vers['R0102AA']}", "R0102AG120", 別表九フォーム].compact.map{ |c| form_attr(c) }.join('')
          @user_inf = render_erb(search_template('eltax-userinf.xml.erb'))
          @form_data = [第六号, 別表四三, 別表九].compact.join("\n")
          render_erb(search_template('eltax.xml.erb'))
        end
      end

      def export_json
        records = kani(export: true)
        [].tap do |res|
          item = {}
          item['date'] = @end_date
          item['debit'] = []
          item['credit'] = []
          records[:jigyouzei].each do |k, dat|
            if dat[:chukan] > 0
              item['credit'] << { 'label' => karibarai_label(k), 'amount' => dat[:chukan] }
            end
            if dat[:chukan] > dat[:zeigaku]
              item['debit'] << { 'label' => '未収地方事業税', 'amount' => dat[:chukan] - dat[:zeigaku] }
            else
              item['credit'] << { 'label' => '未払地方事業税', 'amount' => dat[:zeigaku] - dat[:chukan] }
            end
            item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:zeigaku] } if dat[:zeigaku] > 0
          end
          records[:juminzei].each do |k, dat|
            if dat[:chukan] > 0
              item['credit'] << { 'label' => karibarai_label(k), 'amount' => dat[:chukan] }
            end
            if dat[:chukan] > dat[:zeigaku]
              item['debit'] << { 'label' => '未収都道府県住民税', 'amount' => dat[:chukan] - dat[:zeigaku] }
            else
              item['credit'] << { 'label' => '未払都道府県民税', 'amount' => dat[:zeigaku] - dat[:chukan] }
            end
            item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:zeigaku] } if dat[:zeigaku] > 0
          end
          item['x-editor'] = 'LucaJp'
          res << item
          puts JSON.dump(res)
        end
      end

      def 第六号
        @資本金準備金 = eltax_config('shihon') || it_part_config('shihon_kin')
        render_erb(search_template('el-no6.xml.erb'))
      end

      def 別表四三
        @office_23ku = config.dig('jp', 'eltax', 'office_23ku')
        render_erb(search_template('el-no6-43.xml.erb'))
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
        (@税額.dig(:houjin, :kokuzei) / 1000).floor * 1000
      end

      def 事業税中間納付
        @所得割中間納付
      end

      # TODO: 損失の区分
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
          <AMB00225 />
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

      def karibarai_label(key)
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

      def proc_version
        if @start_date >= Date.parse('2020-4-1')
          { 'R0102AA' => '200', 'R0102AM' => '200' }
        else
          { 'R0102AA' => '190', 'R0102AM' => '190' }
        end
      end

      def lib_path
        __dir__
      end
    end
  end
end
