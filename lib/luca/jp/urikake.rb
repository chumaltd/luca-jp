# frozen_string_literal: true

require 'json'
require 'cgi/escape'
require 'luca_deal'
require 'luca_support'
require 'luca/jp'

module Luca
  module Jp
    class Urikake < LucaDeal::Invoice
      @dirname = 'invoices'

      def report(encoding = nil)
        listed_amount = 0
        encoding ||= 'SJIS'
        customers, total = list
        str = CSV.generate(String.new, headers: false, col_sep: ',', encoding: encoding) do |f|
          customers.map do |c|
            amount = readable(c['unsettled'])
            listed_amount += amount
            f << ['3', '0', '売掛金', c['customer'], c['address'], amount, nil ]
          end
          if total - listed_amount > 0
            f << ['3', '0', '売掛金', 'その他', nil, total - listed_amount, nil ]
          end
          f << ['3', '1', nil, nil, nil, total, nil ]
        end
        File.open('HOI030_3.0.csv', 'w') { |f| f.write(str) }
      end

      def list
        customers = self.class.report(@date, detail: true)
                     .sort_by { |customer| customer['unsettled'] }
                     .reverse
        total = customers.inject(0) { |sum, customer| sum + customer['unsettled'] }

        reports = customers.filter { |customer| 500_000 <= customer['unsettled'] }
        return [reports, total] if reports.length >= 5

        additional = customers
                       .filter { |customer| 500_000 > customer['unsettled'] }
                       .take(5 - reports.length)
        [reports.concat(additional), total]
      end
    end
  end
end
