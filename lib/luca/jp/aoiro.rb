# frozen_string_literal: true

require 'cgi/escape'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca_support/config'
require 'luca/jp/util'

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

      def kani
        @state.pl
        @procedure_code = 'RHO0012'
        @procedure_name = '内国法人の確定申告(青色)'
        @version = '20.0.2'
        @地方法人税課税標準 = ((中小企業の軽減税額 + 一般区分の税額) / 1000).floor * 1000

        @form_sec = ['HOA112', 'HOA116'].map{ |c| form_rdf(c) }.join('')
        #@form_sec = ['HOA201', 'HOE990', 'HOI010', 'HOI040', 'HOI060', 'HOI090', 'HOI100', 'HOI110'].map{ |c| form_rdf(c) }.join('')
        @it = it_part
        @form_data = [別表一, 別表一次葉].join("\n")
        render_erb(search_template('aoiro.xtx.erb'))
      end

      def 別表一
        render_erb(search_template('beppyo1.xml.erb'))
      end

      def 別表一次葉
        render_erb(search_template('beppyo1-next.xml.erb'))
      end

      private

      def 所得金額
        @state.pl_data.dig('HA')
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
