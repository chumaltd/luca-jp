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
    class Aoiro
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
      end

      def kani(export: false)
        @state.pl
        @state.bs
        @法人税中間納付 = prepaid_tax('1851')
        @地方法人税中間納付 = prepaid_tax('1852')
        @法人税額 = 中小企業の軽減税額 + 一般区分の税額
        @確定法人税額 = (@法人税額 / 100).floor * 100
        @地方法人税課税標準 = (@法人税額 / 1000).floor * 1000
        @地方法人税額 = 地方法人税額(@地方法人税課税標準)
        @確定地方法人税額 = (@地方法人税額 / 100).floor * 100

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
          @form_sec = ['HOA112', 'HOA116'].map{ |c| form_rdf(c) }.join('')
          #@form_sec = ['HOA201', 'HOE990', 'HOI010', 'HOI040', 'HOI060', 'HOI090', 'HOI100', 'HOI110'].map{ |c| form_rdf(c) }.join('')
          @it = it_part
          @form_data = [別表一, 別表一次葉].join("\n")
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
            item['credit'] << { 'label' => '未払法人税等', 'amount' => dat[:kokuzei][:zeigaku] - dat[:kokuzei][:chukan] }
          end
          item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:kokuzei][:zeigaku] }
          if dat[:chihou][:chukan] > 0
            item['credit'] << { 'label' => '仮払法人税(地方)', 'amount' => dat[:chihou][:chukan] }
          end
          if dat[:chihou][:chukan] > dat[:chihou][:zeigaku]
            item['debit'] << { 'label' => '未収法人税', 'amount' => dat[:chihou][:chukan] - dat[:chihou][:zeigaku] }
          else
            item['credit'] << { 'label' => '未払法人税等', 'amount' => dat[:chihou][:zeigaku] - dat[:chihou][:chukan] }
          end
          item['debit'] << { 'label' => '法人税、住民税及び事業税', 'amount' => dat[:chihou][:zeigaku] }
          item['x-editor'] = 'LucaJp'
          res << item
          puts JSON.dump(res)
        end
      end

      def 別表一
        render_erb(search_template('beppyo1.xml.erb'))
      end

      def 別表一次葉
        render_erb(search_template('beppyo1-next.xml.erb'))
      end

      private

      # 税引前当期利益をもとに計算
      # 消費税を租税公課に計上している場合、控除済みの金額
      #
      def 所得金額
        @state.pl_data.dig('GA')
      end

      def 中小企業の軽減税率対象所得
        if 所得金額 >= 8_000_000
          8_000_000
        elsif 所得金額 < 0
          0
        else
          (所得金額 / 1000).floor * 1000
        end
      end

      def 中小企業の軽減税額
        中小企業の軽減税率対象所得 * 15 / 100
      end

      def 中小企業の軽減税率対象を超える所得
        if 所得金額 <= 8_000_000
          0
        else
          ((所得金額 - 8_000_000) / 1000).floor * 1000
        end
      end

      def 一般区分の税額
        (中小企業の軽減税率対象を超える所得 * 23.2 / 100).to_i
      end

      def 地方法人税額(地方法人税課税標準)
        (地方法人税課税標準 * 10.3 / 100).to_i
      end

      def lib_path
        __dir__
      end
    end
  end
end
