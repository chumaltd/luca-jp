# frozen_string_literal: true

module Luca
  module Jp
    module Util
      module_function

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

      def prepaid_tax(code)
        #LucaSupport::Code.readable(@bs_data.dig(code) || 0)
        search_end = @end_date.prev_month # exclude year end adjustment
        amount, _ = self.class.net(@start_date.year, @start_date.month, search_end.year, search_end.month, code: code)
        LucaSupport::Code.readable(amount[code] || 0)
      end

      def refund_tax(code)
        credit = credit_amount(code, @start_date.year, @start_date.month, @end_date.year, @end_date.month)
        LucaSupport::Code.readable(credit)
      end

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

      def form_rdf(code)
        "<rdf:li><rdf:description about=\"##{code}\"/></rdf:li>"
      end

      def render_attr(code, val)
        return '' if val.nil? || val.to_s.length == 0

        "<#{code}>#{val}</#{code}>"
      end

      def etax_date(date)
        "<gen:era>#{gengou(date)}</gen:era><gen:yy>#{wareki(date)}</gen:yy><gen:mm>#{date.month}</gen:mm><gen:dd>#{date.day}</gen:dd>"
      end

      def config
        EX_CONF.nil? ? LucaSupport::CONFIG : LucaSupport::CONFIG.merge(EX_CONF)
      end

      def it_part_config(key)
        config.dig('jp', 'it_part', key)
      end

      def beppyo2_config(key)
        config.dig('jp', 'beppyo2', key)
      end

      def gaikyo_config(key)
        config.dig('jp', 'gaikyo', key)
      end

      def eltax_config(key)
        config.dig('jp', 'eltax', key)
      end
    end
  end
end
