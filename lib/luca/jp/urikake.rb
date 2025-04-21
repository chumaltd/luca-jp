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
        format_ver = @date > Date.new(2024, 3, 1) ? 4 : 3
        str = CSV.generate(String.new, headers: false, col_sep: ',', encoding: encoding) do |f|
          customers.map do |c|
            amount = readable(c['unsettled'])
            listed_amount += amount
            if format_ver >= 4
              address = c['tax_id'] ? nil : c['address']
              f << ['3', '0', '売掛金', c['tax_id']&.to_i, nil, c['customer'], address, amount, nil ]
            else
              f << ['3', '0', '売掛金', c['customer'], c['address'], amount, nil ]
            end
          end
          if format_ver >= 4
            f << ['3', '0', '売掛金', nil, nil, 'その他', nil, total - listed_amount, nil ]
            f << ['3', '1', nil, nil, nil, nil, nil, total, nil ]
          else
            f << ['3', '0', '売掛金', 'その他', nil, total - listed_amount, nil ]
            f << ['3', '1', nil, nil, nil, total, nil ]
          end
        end
        STDERR.puts "Writing HOI030_#{format_ver}.0.csv..."
        File.open("HOI030_#{format_ver}.0.csv", 'w') { |f| f.write(str) }
      end

      def list
        customers = self.class.report(@date, detail: true, due: true)
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
