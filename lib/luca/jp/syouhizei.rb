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
        @start_date = Date.new(from_year, from_month, 1)
        @end_date = Date.new(to_year, to_month, 1)
        @dict = LucaRecord::Dict.load('base.tsv')
        @state = LucaBook::State.range(from_year, from_month, to_year, to_month)
      end

      # TODO: 軽減税率売上の識別
      #
      def kani
        @state.pl
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
        <DUA0000><DUA0010>
        <DUA0020 IDREF="KAZEI_KIKAN_FROM"/>
        <DUA0030 IDREF="KAZEI_KIKAN_TO"/>
        <DUA0040 IDREF="NOZEISHA_NM"/>
        </DUA0010></DUA0000>
        <DUB0000>
        #{render_attr('DUB0020', 課税標準額(sales))}
        #{render_attr('DUB0030', 課税標準額(sales))}
        </DUB0000>
        <DUC0000>
        #{render_attr('DUC0020', sales)}
        #{render_attr('DUC0030', sales)}
        </DUC0000>
        <DUD0000>
        #{render_attr('DUD0020', 税額)}
        #{render_attr('DUD0030', 税額)}
        </DUD0000>
        #{render_attr('DUH0030', 税額)}
        <DUI0000>
        #{render_attr('DUI0020', 税額)}
        </DUI0000>
        <DUJ0000>
        #{render_attr('DUJ0020', 譲渡割額)}
        </DUJ0000>
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
        <DVA0000><DVA0010>
        <DVA0020 IDREF="KAZEI_KIKAN_FROM"/>
        <DVA0030 IDREF="KAZEI_KIKAN_TO"/>
        <DVA0040 IDREF="NOZEISHA_NM"/>
        </DVA0010></DVA0000>
        <DVB0000>
        <DVB0010>
        #{render_attr('DVB0020', tax_amount)}
        #{render_attr('DVB0030', tax_amount)}
        </DVB0010>
        <DVB0130>
        #{render_attr('DVB0150', tax_amount)}
        #{render_attr('DVB0160', tax_amount)}
        </DVB0130>
        </DVB0000>
        <DVC0000>
        <DVC0010><kubun_CD>#{LucaSupport::CONFIG.dig('jp', 'syouhizei_kubun')}</kubun_CD>
        </DVC0010>
        #{render_attr('DVC0030', みなし仕入額)}
        #{render_attr('DVC0040', みなし仕入額)}
        </DVC0000>
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
