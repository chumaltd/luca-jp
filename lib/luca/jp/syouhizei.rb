# frozen_string_literal: true

require 'cgi/escape'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca_support/config'
require 'luca/jp/util'

module Luca
  module Jp
    class Syouhizei
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

      # TODO: 軽減税率売上の識別
      #
      def kani
        @state.pl
        @procedure_code = 'RSH0040'
        @procedure_name = '消費税及び地方消費税申告(簡易課税・法人)'
        @version = '20.0.0'
        @form_sec = ['SHA020', 'SHB047', 'SHB067'].map{ |c| form_rdf(c) }.join('')

        税率 = BigDecimal('7.8') # percent
        地方税率 = BigDecimal('2.2')

        @sales = @state.pl_data.dig('A0') * 100 / (100 + 税率 + 地方税率).floor
        @tax_amount = (課税標準額(@sales) * 税率 / 100).floor
        @みなし仕入税額 = (@tax_amount * みなし仕入率(LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')) / 100).floor
        @税額 = LucaSupport::Code.readable(((@tax_amount - @みなし仕入税額) / 100).floor * 100)
        @譲渡割額 = (@税額 * 地方税率 / (税率*100)).floor * 100
        # TODO: load 中間納付
        @中間納付額 = 0
        @地方税中間納付額 = 0

        @it = it_part
        @form_data = [申告書簡易課税, 付表四の三, 付表五の三].join("\n")
        render_erb(search_template('consumption.xtx.erb'))
      end

      def 申告書簡易課税
        render_erb(search_template('syouhizei-shinkoku-kanni.xml.erb'))
      end

      def 付表四の三
        render_erb(search_template('fuhyo43.xml.erb'))
      end

      def 付表五の三
        render_erb(search_template('fuhyo53.xml.erb'))
      end

      private

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

      def 課税標準額(課税資産の譲渡等の対価の額)
        (課税資産の譲渡等の対価の額 / 1000).floor * 1000
      end

      def みなし仕入率(事業区分)
        {
          1 => 90,
          2 => 80,
          3 => 70,
          4 => 60,
          5 => 50,
          6 => 40
        }[事業区分]
      end

      def 事業区分
        tags = case LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')
               when 1
                 ['ABL00030', 'ABL00040', 'ABL00050']
               when 2
                 ['ABL00060', 'ABL00070', 'ABL00080']
               when 3
                 ['ABL00090', 'ABL00100', 'ABL00110']
               when 4
                 ['ABL00120', 'ABL00130', 'ABL00140']
               when 5
                 ['ABL00150', 'ABL00160', 'ABL00170']
               when 6
                 ['ABL00180', 'ABL00190', 'ABL00200']
               else
                 return nil
               end
        amount = render_attr(tags[1], LucaSupport::Code.readable(@sales))
        share = render_attr(tags[2], '100.0')
        render_attr(tags[0], [amount, share].join(''))
      end

      def lib_path
        __dir__
      end
    end
  end
end
