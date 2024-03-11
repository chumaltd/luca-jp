# frozen_string_literal: true

require 'json'
require 'cgi/escape'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'
require 'luca/jp/util'

module Luca
  module Jp
    class Syouhizei < LucaBook::State
      include LucaSupport::View
      include Luca::Jp::Common
      include Luca::Jp::ItPart
      include Luca::Jp::Util

      @dirname = 'journals'
      @record_type = 'raw'

      # TODO: 軽減税率売上の識別
      #
      def kani(export: false)
        @２割特例 = config.dig('jp', 'syouhizei_kubun') == 2023
        set_pl(4)
        set_bs(4)
        @issue_date = Date.today
        @company = CGI.escapeHTML(config.dig('company', 'name'))
        @software = 'LucaJp'
        @shinkoku_kbn = '1' # 確定申告
        税率 = BigDecimal('7.8') # percent
        地方税率 = BigDecimal('2.2')

        @sales = @pl_data.dig('A0') * 100 / (100 + 税率 + 地方税率).floor
        @tax_amount = (課税標準額(@sales) * 税率 / 100).floor
        @基準期間の課税売上高 = LucaSupport::Code.readable(基準期間の課税売上高(税率 + 地方税率))
        @みなし仕入税額 = (@tax_amount * みなし仕入率(config.dig('jp', 'syouhizei_kubun')) / 100).floor
        @税額 = LucaSupport::Code.readable(((@tax_amount - @みなし仕入税額) / 100).floor * 100)
        @譲渡割額 = (@税額 * 地方税率 / (税率*100)).floor * 100
        @中間納付額 = 消費税中間納付額
        @地方税中間納付額 = 地方消費税中間納付額

        if export
          {
            kokuzei: {
              zeigaku: @税額,
              chukan: @中間納付額
            },
            chihou: {
              zeigaku: @譲渡割額,
              chukan: @地方税中間納付額
            }
          }
        else
          @procedure_code = 'RSH0040'
          @procedure_name = '消費税及び地方消費税申告(簡易課税・法人)'
          @form_vers = proc_version
          @version = @form_vers['proc']
          @it = it_part
          @form_sec = if @２割特例
                        ['SHA020', 'SHB070'].map{ |c| form_rdf(c) }.join('')
                      else
                        ['SHA020', 'SHB047', 'SHB067'].map{ |c| form_rdf(c) }.join('')
                      end
          @form_data = if @２割特例
                         [申告書簡易課税, 付表六].join("\n")
                       else
                         [申告書簡易課税, 付表四の三, 付表五の三].join("\n")
                       end
          render_erb(search_template('consumption.xtx.erb'))
        end
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

      def 付表六
        render_erb(search_template('fuhyo6.xml.erb'))
      end

      def export_json
        dat = kani(export: true)
        [].tap do |res|
          item = {}
          item['date'] = @end_date
          item['debit'] = []
          item['credit'] = []
          if dat[:kokuzei][:chukan] > 0
            item['credit'] << { 'label' => '仮払消費税', 'amount' => dat[:kokuzei][:chukan] }
          end
          if dat[:kokuzei][:chukan] > dat[:kokuzei][:zeigaku]
            item['debit'] << { 'label' => '未収消費税等', 'amount' => dat[:kokuzei][:chukan] - dat[:kokuzei][:zeigaku] }
          else
            item['credit'] << { 'label' => '未払消費税等', 'amount' => dat[:kokuzei][:zeigaku] - dat[:kokuzei][:chukan] }
          end
          item['debit'] << { 'label' => '消費税', 'amount' => dat[:kokuzei][:zeigaku] }
          if dat[:chihou][:chukan] > 0
            item['credit'] << { 'label' => '仮払地方消費税', 'amount' => dat[:chihou][:chukan] }
          end
          if dat[:chihou][:chukan] > dat[:chihou][:zeigaku]
            item['debit'] << { 'label' => '未収消費税等', 'amount' => dat[:chihou][:chukan] - dat[:chihou][:zeigaku] }
          else
            item['credit'] << { 'label' => '未払消費税等', 'amount' => dat[:chihou][:zeigaku] - dat[:chihou][:chukan] }
          end
          item['debit'] << { 'label' => '消費税', 'amount' => dat[:chihou][:zeigaku] }
          item['x-editor'] = 'LucaJp'
          res << item
          puts JSON.dump(res)
        end
      end

      private

      def 課税標準額(課税資産の譲渡等の対価の額)
        (課税資産の譲渡等の対価の額 / 1000).floor * 1000
      end

      def 基準期間の課税売上高(税率)
        基準日 = @end_date.prev_year(2)
        from_d, to_d = LucaBook::Util.current_fy(基準日)
        state = LucaBook::State.range(from_d.year, from_d.month, to_d.year, to_d.month)
        state.pl
        (state.pl_data.dig('A0') * 100 / (100 + 税率)).floor
      end

      # 2023は２割特例
      #
      def みなし仕入率(事業区分)
        {
          1 => 90,
          2 => 80,
          3 => 70,
          4 => 60,
          5 => 50,
          6 => 40,
          2023 => 80
        }[事業区分]
      end

      def 事業区分
        tags = case config.dig('jp', 'syouhizei_kubun')
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

      def proc_version
        if @end_date >= Date.parse('2023-10-1')
          { 'proc' => '23.0.0', 'SHA020' => '9.0' }
        elsif @end_date >= Date.parse('2021-4-1')
          { 'proc' => '20.0.1', 'SHA020' => '7.1' }
        else
          { 'proc' => '20.0.0', 'SHA020' => '7.0' }
        end
      end

      def lib_path
        __dir__
      end
    end
  end
end
