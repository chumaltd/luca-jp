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
