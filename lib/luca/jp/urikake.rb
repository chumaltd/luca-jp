# frozen_string_literal: true

require 'json'
require 'cgi/escape'
require 'luca_deal'
require 'luca_support'
require 'luca_support/config'
require 'luca/jp'

module Luca
  module Jp
    class Urikake < LucaDeal::Invoice
      @dirname = 'invoices'

      def report(total = nil, encoding = nil)
        listed_amount = 0
        encoding ||= 'SJIS'
        str = CSV.generate(String.new, headers: false, col_sep: ',', encoding: encoding) do |f|
          list.map do |invoice|
            amount = readable(invoice.dig('subtotal', 0, 'items') + invoice.dig('subtotal', 0, 'tax'))
            listed_amount += amount
            f << ['3', '0', '売掛金', invoice.dig('customer', 'name'), invoice.dig('customer', 'address'), amount, nil ]
          end
          if total
            f << ['3', '0', '売掛金', 'その他', nil, total - listed_amount, nil ]
            f << ['3', '1', nil, nil, nil, total, nil ]
          else
            f << ['3', '1', nil, nil, nil, listed_amount, nil ]
          end
        end
        File.open('HOI030_3.0.csv', 'w') { |f| f.write(str) }
      end

      def list
        invoices = self.class.asof(@date.year, @date.month)
                     .map { |dat, _path| dat }
                     .sort_by { |invoice| invoice.dig('subtotal', 0, 'items') }
                     .reverse

        reports = invoices.filter { |invoice| 500_000 <= invoice['subtotal'].inject(0) { |sum, i| sum + i['items'] + i['tax'] } }
        return reports if reports.length >= 5

        additional = invoices
                       .filter { |invoice| 500_000 > invoice['subtotal'].inject(0) { |sum, i| sum + i['items'] + i['tax'] } }
                       .take(5 - reports.length)
        reports.concat(additional)
      end
    end
  end
end
