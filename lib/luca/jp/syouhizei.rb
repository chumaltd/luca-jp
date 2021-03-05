# frozen_string_literal: true

require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca_support/config'

module Luca
  module Jp
    class Syouhizei
      include LucaSupport::View

      def initialize(from_year, from_month, to_year = from_year, to_month = from_month)
        @start_date = Date.new(from_year.to_i, from_month.to_i, 1)
        @end_date = Date.new(to_year.to_i, to_month.to_i, 1)
        @dict = LucaRecord::Dict.load('base.tsv')
        @state = LucaBook::State.range(from_year, from_month, to_year, to_month)
      end

      # TODO: 軽減税率売上の識別
      #
      def kani
        @state.pl
        @procedure_code = 'RSH0040'
        #@version = ''
        @it = it_part
        @form_sec = ['SHB047', 'SHB067'].map{ |c| form_rdf(c) }.join('')
        @form_data = [付表四の三, 付表五の三].join("\n")
        render_erb(search_template('consumption.xtx.erb'))
      end

      def 付表四の三
        税率 = BigDecimal('7.8') # percent
        sales = @state.pl_data.dig('A0') * 100 / (100 + 10).floor
        tax_amount = (課税標準額(sales) * 税率 / 100).floor
        みなし仕入額 = (tax_amount * みなし仕入率(LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')) / 100).floor
        税額 = LucaSupport::Code.readable(((tax_amount - みなし仕入額) / 100).floor * 100)
        譲渡割額 = (税額 * 22 / (78*100)).floor * 100

        <<~EOS
        <SHB047 page="1" VR="1" id="SHB047">
        <DUA00000><DUA00010>
        <DUA00020 IDREF="KAZEI_KIKAN_FROM"/>
        <DUA00030 IDREF="KAZEI_KIKAN_TO"/>
        </DUA00010>
        <DUA00040 IDREF="NOZEISHA_NM"/>
        </DUA00000>
        <DUB00000>
        #{render_attr('DUB00020', 課税標準額(sales))}
        #{render_attr('DUB00030', 課税標準額(sales))}
        </DUB00000>
        <DUC00000>
        #{render_attr('DUC00020', LucaSupport::Code.readable(sales))}
        #{render_attr('DUC00030', LucaSupport::Code.readable(sales))}
        </DUC00000>
        <DUD00000>
        #{render_attr('DUD00020', 税額)}
        #{render_attr('DUD00030', 税額)}
        </DUD00000>
        #{render_attr('DUH00030', 税額)}
        <DUI00000>
        #{render_attr('DUI00020', 税額)}
        </DUI00000>
        <DUJ00000>
        #{render_attr('DUJ00020', 譲渡割額)}
        </DUJ00000>
        </SHB047>
        EOS
      end

      def 付表五の三
        税率 = BigDecimal('7.8') # percent
        sales = @state.pl_data.dig('A0') * 100 / (100 + 10).floor
        tax_amount = (課税標準額(sales) * 税率 / 100).floor
        みなし仕入額 = (tax_amount * みなし仕入率(LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')) / 100).floor
        税額 = LucaSupport::Code.readable(((tax_amount - みなし仕入額) / 100).floor * 100)
        譲渡割額 = (税額 * 22 / (78*100)).floor * 100

        <<~EOS
        <SHB067 page="1" VR="1" id="SHB067"><SHB067-1 page="1">
        <DVA00000><DVA00010>
        <DVA00020 IDREF="KAZEI_KIKAN_FROM"/>
        <DVA00030 IDREF="KAZEI_KIKAN_TO"/>
        </DVA00010>
        <DVA00040 IDREF="NOZEISHA_NM"/>
        </DVA00000>
        <DVB00000>
        <DVB00010>
        #{render_attr('DVB00020', tax_amount)}
        #{render_attr('DVB00030', tax_amount)}
        </DVB00010>
        <DVB00130>
        #{render_attr('DVB00150', tax_amount)}
        #{render_attr('DVB00160', tax_amount)}
        </DVB00130>
        </DVB00000>
        <DVC00000>
        <DVC00010><kubun_CD>#{LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')}</kubun_CD>
        </DVC00010>
        #{render_attr('DVC00030', みなし仕入額)}
        #{render_attr('DVC00040', みなし仕入額)}
        </DVC00000>
        </SHB067-1></SHB067>
        EOS
      end

      private

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

      def gengou(date)
        if date >= Date.new(2019, 5, 1)
          5
        else
          4
        end
      end

      def wareki(date)
        if date >= Date.new(2019, 5, 1)
          date.year - 2018
        else
          date.year - 1988
        end
      end

      def form_rdf(code)
        "<rdf:li><rdf:description about=\"##{code}\"/></rdf:li>"
      end

      def render_attr(code, val)
        "<#{code}>#{val}</#{code}>\n"
      end

      # TODO: supply instance variables related to each procedure
      #
      def it_part
        render_erb(search_template('it-part.xtx.erb'))
      end

      def lib_path
        __dir__
      end
    end
  end
end
