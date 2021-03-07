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
        LucaSupport::Code.readable(@state.bs_data.dig(code) || 0)
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
        "<#{code}>#{val}</#{code}>"
      end

      # TODO: supply instance variables related to each procedure
      #
      def it_part
        render_erb(search_template('it-part.xtx.erb'))
      end
    end
  end
end