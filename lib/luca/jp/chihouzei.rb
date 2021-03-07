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
    class Chihouzei
      include LucaSupport::View
      include Luca::Jp::Util

      def initialize(from_year, from_month, to_year = from_year, to_month = from_month)
        @start_date = Date.new(from_year.to_i, from_month.to_i, 1)
        @end_date = Date.new(to_year.to_i, to_month.to_i, -1)
        @issue_date = Date.today
        @company = CGI.escapeHTML(LucaSupport::CONFIG.dig('company', 'name'))
        @dict = LucaRecord::Dict.load('base.tsv')
        @software = 'LucaJp'
        @state = LucaBook::State.range(from_year, from_month, to_year, to_month)
        @jimusho_code = LucaSupport::CONFIG.dig('jp', 'eltax', 'jimusho_code')
        @jimusho_name = '都税事務所長'
      end

      def kani(export: false)
        @state.pl
        @state.bs

        @均等割 = 70000
        @法人税割課税標準 = 法人税割課税標準
        @確定法人税割 = (法人税割 / 100).floor * 100
        @地方特別法人事業税中間納付 = prepaid_tax('1854')
        @所得割中間納付 = prepaid_tax('1855')
        @法人税割中間納付 = prepaid_tax('1859')
        @均等割中間納付 = prepaid_tax('185A')
        @所得割 = 所得割400万以下 + 所得割800万以下 + 所得割800万超
        if export
          {
            jigyouzei: {
              shotoku: {
                zeigaku: @所得割,
                chukan: @所得割中間納付
              },
              tokubetsu: {
                zeigaku: 地方法人特別税(@所得割),
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
          @form_sec = ['R0102AA190', 'R0102AG120'].map{ |c| form_attr(c) }.join('')
          @user_inf = render_erb(search_template('el-userinf.xml.erb'))
          @form_data = [第六号, 別表四三].join("\n")
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
              item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:chukan] - dat[:zeigaku] }
            else
              item['credit'] << { 'label' => '未払地方事業税', 'amount' => dat[:zeigaku] - dat[:chukan] }
            end
            item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:zeigaku] }
          end
          records[:juminzei].each do |k, dat|
            if dat[:chukan] > 0
              item['credit'] << { 'label' => karibarai_label(k), 'amount' => dat[:chukan] }
            end
            if dat[:chukan] > dat[:zeigaku]
              item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:chukan] - dat[:zeigaku] }
            else
              item['credit'] << { 'label' => '未払都道府県民税', 'amount' => dat[:zeigaku] - dat[:chukan] }
            end
            item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:zeigaku] }
          end
          item['x-editor'] = 'LucaJp'
          res << item
          puts JSON.dump(res)
        end
      end

      def 第六号
        render_erb(search_template('el-no6.xml.erb'))
      end

      def 別表四三
        @office_23ku = LucaSupport::CONFIG.dig('jp', 'eltax', 'office_23ku')
        render_erb(search_template('el-no6-43.xml.erb'))
      end

      private

      def 法人税割課税標準
        national_tax = Luca::Jp::Aoiro.new(@start_date.year, @start_date.month, @end_date.year, @end_date.month).kani(export: true)
        (national_tax[:kokuzei][:zeigaku] / 1000).floor * 1000
      end

      def 法人税割
        (@法人税割課税標準 * 7 / 100).floor
      end

      def 地方法人特別税(事業税)
        ((事業税 * 37 / 100) / 100).floor * 100
      end

      def 所得金額
        LucaSupport::Code.readable(@state.pl_data.dig('GA'))
      end

      def 所得400万以下
        if 所得金額 >= 4_000_000
          4_000_000
        else
          (所得金額 / 1000).floor * 1000
        end
      end

      def 所得割400万以下
        ((所得400万以下 * 3.5 / 100) / 100).floor * 100
      end

      def 所得800万以下
        if 所得金額 <= 4_000_000
          0
        elsif 所得金額 >= 8_000_000
          4_000_000
        else
          ((所得金額 - 4_000_000) / 1000).floor * 1000
        end
      end

      def 所得割800万以下
        ((所得800万以下 * 5.3 / 100) / 100).floor * 100
      end

      def 所得800万超
        if 所得金額 <= 8_000_000
          0
        else
          ((所得金額 - 8_000_000) / 1000).floor * 1000
        end
      end

      def 所得割800万超
        ((所得800万超 * 7.0 / 100) / 100).floor * 100
      end

      def 事業税中間納付
        @所得割中間納付
      end

      def form_attr(code)
        "<FORM_ATTR><FORM_ID>#{code}</FORM_ID><FORM_NAME></FORM_NAME><FORM_FILE_NAME></FORM_FILE_NAME><FORM_XSL_NAME></FORM_XSL_NAME></FORM_ATTR>"
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
        when :hojinzei
          '仮払地方税法人税割'
        when :kinto
          '仮払地方税均等割'
        end
      end

      def lib_path
        __dir__
      end
    end
  end
end